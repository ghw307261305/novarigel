@IsTest
private class TravelTimeControllerTest {
  private class DistanceMatrixMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');

      String mode = 'unknown';
      if (req.getEndpoint() != null) {
        for (String param : req.getEndpoint().split('&')) {
          if (param.startsWith('mode=')) {
            mode = param.substring(5);
            break;
          }
        }
      }

      String body = buildBody(mode);
      res.setBody(body);
      return res;
    }

    private String buildBody(String mode) {
      Map<String, Object> duration = new Map<String, Object>{
        'text' => '10 mins - ' + mode,
        'value' => 600
      };
      Map<String, Object> element = new Map<String, Object>{
        'status' => 'OK',
        'duration' => duration
      };
      Map<String, Object> row = new Map<String, Object>{
        'elements' => new List<Object>{ element }
      };
      Map<String, Object> payload = new Map<String, Object>{
        'status' => 'OK',
        'rows' => new List<Object>{ row }
      };

      return JSON.serialize(payload);
    }
  }

  @IsTest
  static void testGetTravelTimesSuccess() {
    Test.setMock(HttpCalloutMock.class, new DistanceMatrixMock());

    Test.startTest();
    List<TravelTimeController.TravelOption> results = TravelTimeController.getTravelTimes(
      'Beijing',
      'Shanghai'
    );
    Test.stopTest();

    System.assertEquals(
      4,
      results.size(),
      'Should return travel time for each supported mode'
    );
    Set<String> modes = new Set<String>();
    for (TravelTimeController.TravelOption option : results) {
      System.assertEquals('OK', option.status);
      System.assertNotEquals(null, option.durationText);
      System.assertEquals(Integer.valueOf(600), option.durationValue);
      modes.add(option.mode);
    }

    System.assert(
      modes.contains('transit_mixed'),
      'transit_mixed result should be present'
    );
  }

  @IsTest
  static void testGetTravelTimesMissingAddress() {
    try {
      TravelTimeController.getTravelTimes('', 'Shanghai');
      System.assert(false, 'Expected exception for missing origin');
    } catch (AuraHandledException ex) {
      System.assert(ex.getMessage().contains('必須'));
    }
  }
}
