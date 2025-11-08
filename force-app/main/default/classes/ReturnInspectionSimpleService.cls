public with sharing class ReturnInspectionSimpleService {
  private static final String NC_LAMBDA = 'callout:LambdaAI';

  public class ImageReq {
    public String filename;
    public String contentType;
    public String data_base64;
  }

  public class FlowRequest {
    @InvocableVariable
    public Id recordId;
  }

  public class LambdaResult {
    @InvocableVariable
    public String rawJson;

    @AuraEnabled
    public String getRawJson() {
      return rawJson;
    }

    public LambdaResult() {
    }

    public LambdaResult(String rawJson) {
      this.rawJson = rawJson;
    }
  }

  @InvocableMethod(
    label='Inspect Return Images'
    description='Calls the Lambda service to inspect return images for the provided records.'
  )
  public static List<LambdaResult> inspectReturns(List<FlowRequest> requests) {
    if (requests == null || requests.isEmpty()) {
      throw new FlowException('At least one request is required.');
    }

    Set<Id> recordIds = new Set<Id>();
    for (FlowRequest req : requests) {
      if (req == null || req.recordId == null) {
        throw new FlowException('recordId is required');
      }
      recordIds.add(req.recordId);
    }

    Map<Id, List<ImageReq>> imagesByRecord = buildImages(recordIds);

    List<LambdaResult> results = new List<LambdaResult>();
    for (FlowRequest req : requests) {
      List<ImageReq> images = imagesByRecord.get(req.recordId);
      if (images == null || images.isEmpty()) {
        throw new FlowException(
          'No files found for record ' + req.recordId + '.'
        );
      }
      try {
        results.add(callLambda(req.recordId, images));
      } catch (AuraHandledException ex) {
        throw new FlowException(ex.getMessage());
      }
    }
    return results;
  }

  @AuraEnabled
  public static LambdaResult inspectByRecord(Id recordId) {
    if (recordId == null) {
      throw new AuraHandledException('recordId is required');
    }

    Set<Id> singleRecord = new Set<Id>();
    singleRecord.add(recordId);
    Map<Id, List<ImageReq>> imagesByRecord = buildImages(singleRecord);
    List<ImageReq> images = imagesByRecord.get(recordId);
    if (images == null || images.isEmpty()) {
      throw new AuraHandledException('No files found for this record.');
    }
    return callLambda(recordId, images);
  }

  private static LambdaResult callLambda(Id recordId, List<ImageReq> images) {
    Map<String, Object> payload = new Map<String, Object>{
      'recordId' => (String) recordId,
      'images' => images
    };

    String resJson = callLambdaJson(payload);
    return new LambdaResult(resJson);
  }

  private static Map<Id, List<ImageReq>> buildImages(Set<Id> recordIds) {
    Map<Id, List<ImageReq>> imagesByRecord = new Map<Id, List<ImageReq>>();
    for (Id recordId : recordIds) {
      imagesByRecord.put(recordId, new List<ImageReq>());
    }

    if (recordIds.isEmpty()) {
      return imagesByRecord;
    }

    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId, LinkedEntityId
      FROM ContentDocumentLink
      WHERE LinkedEntityId IN :recordIds
    ];

    if (links.isEmpty()) {
      return imagesByRecord;
    }

    Set<Id> contentDocumentIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
      contentDocumentIds.add(link.ContentDocumentId);
    }

    Map<Id, ContentVersion> latestVersionByDoc = new Map<Id, ContentVersion>();
    if (!contentDocumentIds.isEmpty()) {
      for (ContentVersion cv : [
        SELECT
          Id,
          ContentDocumentId,
          Title,
          FileType,
          PathOnClient,
          VersionData,
          VersionNumber
        FROM ContentVersion
        WHERE ContentDocumentId IN :contentDocumentIds
        ORDER BY ContentDocumentId, VersionNumber DESC
      ]) {
        if (!latestVersionByDoc.containsKey(cv.ContentDocumentId)) {
          latestVersionByDoc.put(cv.ContentDocumentId, cv);
        }
      }
    }

    for (ContentDocumentLink link : links) {
      ContentVersion latest = latestVersionByDoc.get(link.ContentDocumentId);
      if (latest == null) {
        continue;
      }
      List<ImageReq> images = imagesByRecord.get(link.LinkedEntityId);
      if (images == null) {
        images = new List<ImageReq>();
        imagesByRecord.put(link.LinkedEntityId, images);
      }
      images.add(buildImage(latest));
    }

    return imagesByRecord;
  }

  private static ImageReq buildImage(ContentVersion cv) {
    ImageReq img = new ImageReq();
    img.filename = deriveFileName(cv);
    img.contentType = guessContentType(cv.FileType, img.filename);
    img.data_base64 = EncodingUtil.base64Encode(cv.VersionData);
    return img;
  }

  private static String callLambdaJson(Map<String, Object> payload) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(NC_LAMBDA);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(120000);
    req.setBody(JSON.serialize(payload));

    Http http = new Http();
    HttpResponse res = http.send(req);
    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
      throw new AuraHandledException(
        'Lambda error: ' + res.getStatus() + ' ' + res.getBody()
      );
    }
    return res.getBody();
  }

  private static String deriveFileName(ContentVersion cv) {
    String base = cv.PathOnClient;
    if (String.isBlank(base)) {
      base = cv.Title;
    }
    String ext = guessExt(cv.FileType);
    if (String.isBlank(base)) {
      return 'upload' + ext;
    }

    if (base.contains('/')) {
      base = base.substring(base.lastIndexOf('/') + 1);
    }
    if (base.contains('\\')) {
      base = base.substring(Math.max(base.lastIndexOf('\\') + 1, 0));
    }

    if (!base.contains('.')) {
      base += ext;
    }
    if (base.length() > 200) {
      Integer dot = base.lastIndexOf('.');
      String nameOnly = (dot > 0) ? base.substring(0, dot) : base;
      String suffix = (dot > 0) ? base.substring(dot) : ext;
      base = nameOnly.left(150) + suffix;
    }
    return base;
  }

  private static String guessExt(String fileType) {
    if (fileType == null) {
      return '.bin';
    }
    String t = fileType.toUpperCase();
    if (t == 'PNG') {
      return '.png';
    }
    if (t == 'JPG' || t == 'JPEG') {
      return '.jpg';
    }
    if (t == 'GIF') {
      return '.gif';
    }
    if (t == 'WEBP') {
      return '.webp';
    }
    if (t == 'BMP') {
      return '.bmp';
    }
    return '.bin';
  }

  private static String guessContentType(String fileType, String fileName) {
    if (fileType != null) {
      String t = fileType.toUpperCase();
      if (t == 'PNG') {
        return 'image/png';
      }
      if (t == 'JPG' || t == 'JPEG') {
        return 'image/jpeg';
      }
      if (t == 'GIF') {
        return 'image/gif';
      }
      if (t == 'WEBP') {
        return 'image/webp';
      }
      if (t == 'BMP') {
        return 'image/bmp';
      }
    }
    String fn = (fileName != null) ? fileName.toLowerCase() : '';
    if (fn.endsWith('.png')) {
      return 'image/png';
    }
    if (fn.endsWith('.jpg') || fn.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (fn.endsWith('.gif')) {
      return 'image/gif';
    }
    if (fn.endsWith('.webp')) {
      return 'image/webp';
    }
    if (fn.endsWith('.bmp')) {
      return 'image/bmp';
    }
    return 'application/octet-stream';
  }
}
