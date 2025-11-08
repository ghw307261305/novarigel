@IsTest
private class ReturnInspectionSimpleServiceTest {
  private class LambdaMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('{"status":"ok"}');
      return res;
    }
  }

  @IsTest
  static void testInspectReturnsAndAuraMethod() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    ContentVersion version = new ContentVersion(
      Title = 'Test Image',
      PathOnClient = 'test-image.jpg',
      VersionData = Blob.valueOf('fake image data'),
      IsMajorVersion = true
    );
    insert version;

    ContentDocumentLink link = new ContentDocumentLink(
      ContentDocumentId = version.ContentDocumentId,
      LinkedEntityId = acc.Id,
      ShareType = 'V'
    );
    insert link;

    Test.setMock(HttpCalloutMock.class, new LambdaMock());

    ReturnInspectionSimpleService.FlowRequest request = new ReturnInspectionSimpleService.FlowRequest();
    request.recordId = acc.Id;

    Test.startTest();
    List<ReturnInspectionSimpleService.LambdaResult> flowResults = ReturnInspectionSimpleService.inspectReturns(
      new List<ReturnInspectionSimpleService.FlowRequest>{ request }
    );
    ReturnInspectionSimpleService.LambdaResult auraResult = ReturnInspectionSimpleService.inspectByRecord(
      acc.Id
    );
    Test.stopTest();

    System.assertEquals(1, flowResults.size(), 'Expected one Flow result');
    System.assertEquals(
      '{"status":"ok"}',
      flowResults[0].rawJson,
      'Unexpected Flow response'
    );
    System.assertEquals(
      '{"status":"ok"}',
      auraResult.rawJson,
      'Unexpected Aura response'
    );
  }

  @IsTest
  static void testInspectReturnsMissingFile() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    ReturnInspectionSimpleService.FlowRequest request = new ReturnInspectionSimpleService.FlowRequest();
    request.recordId = acc.Id;

    Test.startTest();
    Exception ex;
    try {
      ReturnInspectionSimpleService.inspectReturns(
        new List<ReturnInspectionSimpleService.FlowRequest>{ request }
      );
    } catch (Exception e) {
      ex = e;
    }
    Test.stopTest();

    System.assertNotEquals(
      null,
      ex,
      'Expected an exception when no files are present'
    );
    System.assertEquals(
      'System.FlowException: No files found for record ' + acc.Id + '.',
      String.valueOf(ex)
    );
  }
}
