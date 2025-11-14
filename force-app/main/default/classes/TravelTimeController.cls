public with sharing class TravelTimeController {
  private static final List<String> SUPPORTED_MODES = new List<String>{
    'driving',
    'walking',
    'transit'
  };

  public class TravelOption {
    @AuraEnabled
    public String mode;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String durationText;
    @AuraEnabled
    public Integer durationValue;
    @AuraEnabled
    public String errorMessage;
  }

  @AuraEnabled(cacheable=false)
  public static List<TravelOption> getTravelTimes(
    String origin,
    String destination
  ) {
    if (String.isBlank(origin) || String.isBlank(destination)) {
      throw new AuraHandledException('出発地と到着地は必須です。');
    }

    List<TravelOption> results = new List<TravelOption>();

    for (String mode : SUPPORTED_MODES) {
      results.add(fetchTravelTime(origin, destination, mode));
    }

    return results;
  }

  @TestVisible
  private static TravelOption fetchTravelTime(
    String origin,
    String destination,
    String mode
  ) {
    Http http = new Http();
    HttpRequest request = new HttpRequest();
    request.setMethod('GET');
    request.setTimeout(20000);
    request.setEndpoint(buildEndpoint(origin, destination, mode));

    HttpResponse response = http.send(request);

    TravelOption option = new TravelOption();
    option.mode = mode;

    if (response == null) {
      option.status = 'ERROR';
      option.errorMessage = 'Google Maps API からの応答がありません。';
      return option;
    }

    if (response.getStatusCode() != 200) {
      option.status = 'ERROR';
      option.errorMessage =
        'Google Maps API の呼び出しに失敗しました。ステータスコード：' +
        response.getStatusCode();
      return option;
    }

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      response.getBody()
    );
    option.status = (String) payload.get('status');

    if (!'OK'.equalsIgnoreCase(option.status)) {
      option.errorMessage = (String) payload.get('error_message');
      if (String.isBlank(option.errorMessage)) {
        option.errorMessage = 'Google Maps のステータス：' + option.status;
      }
      return option;
    }

    List<Object> rows = (List<Object>) payload.get('rows');
    if (rows == null || rows.isEmpty()) {
      option.status = 'ERROR';
      option.errorMessage = '経路情報が返されませんでした。';
      return option;
    }

    Map<String, Object> row = (Map<String, Object>) rows.get(0);
    List<Object> elements = (List<Object>) row.get('elements');
    if (elements == null || elements.isEmpty()) {
      option.status = 'ERROR';
      option.errorMessage = '経路情報が返されませんでした。';
      return option;
    }

    Map<String, Object> element = (Map<String, Object>) elements.get(0);
    String elementStatus = (String) element.get('status');
    option.status = elementStatus;

    if (!'OK'.equalsIgnoreCase(elementStatus)) {
      option.errorMessage = 'Google Maps のステータス：' + elementStatus;
      return option;
    }

    Map<String, Object> duration = (Map<String, Object>) element.get(
      'duration'
    );
    if (duration != null) {
      option.durationText = (String) duration.get('text');
      Object valueObj = duration.get('value');
      if (valueObj instanceof Integer) {
        option.durationValue = (Integer) valueObj;
      } else if (valueObj instanceof Long) {
        option.durationValue = Integer.valueOf(((Long) valueObj).intValue());
      }
    }

    return option;
  }

  private static String buildEndpoint(
    String origin,
    String destination,
    String mode
  ) {
    String baseUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';
    StringBuilder endpoint = new StringBuilder(baseUrl);
    endpoint.append('?origins=' + EncodingUtil.urlEncode(origin, 'UTF-8'));
    endpoint.append(
      '&destinations=' + EncodingUtil.urlEncode(destination, 'UTF-8')
    );
    endpoint.append('&mode=' + EncodingUtil.urlEncode(mode, 'UTF-8'));
    endpoint.append('&language=ja');
    if ('transit'.equalsIgnoreCase(mode)) {
      endpoint.append('&departure_time=now');
    }

    String apiKey = System.Label.Google_Maps_API_Key;
    if (String.isBlank(apiKey)) {
      throw new AuraHandledException(
        'Google Maps API キーが設定されていません。カスタムラベル Google_Maps_API_Key に値を入力してください。'
      );
    }

    endpoint.append('&key=' + EncodingUtil.urlEncode(apiKey, 'UTF-8'));
    return endpoint.toString();
  }
}
