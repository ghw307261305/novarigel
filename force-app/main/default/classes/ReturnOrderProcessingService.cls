public with sharing class ReturnOrderProcessingService {
    public class Request {
        @AuraEnabled
        public String orderNumber;

        @AuraEnabled
        public String productCode;

        @AuraEnabled
        public Decimal quantity;

        @AuraEnabled
        public String returnReason;
    }

    public class Response {
        @AuraEnabled
        public Boolean success;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String primaryMessage;

        @AuraEnabled
        public String secondaryMessage;

        @AuraEnabled
        public String returnOrderNumber;

        @AuraEnabled
        public String caseNumber;

        @AuraEnabled
        public ReturnEligibilityService.EvaluationResult evaluation;
    }

    private class FlowOutcome {
        Boolean success = false;
        String returnOrderNumber;
        String caseNumber;
        String errorMessage;
    }

    @AuraEnabled
    public static Response processReturn(Request request) {
        if (request == null) {
            throw new AuraHandledException('返品手続きを進めるには注文情報が必要です。');
        }

        String normalizedOrderNumber = request.orderNumber != null ? request.orderNumber.trim() : null;
        String normalizedProductCode = request.productCode != null ? request.productCode.trim() : null;
        String normalizedReturnReason = request.returnReason != null ? request.returnReason.trim() : null;
        Decimal quantity = request.quantity;

        validateInputs(normalizedOrderNumber, normalizedProductCode, quantity);

        ReturnEligibilityService.EvaluationResult evaluation = ReturnEligibilityService.evaluateProductReturn(
            normalizedProductCode,
            normalizedReturnReason
        );

        Response response = new Response();
        response.evaluation = evaluation;

        if (evaluation == null) {
            response.success = false;
            response.status = 'EVALUATION_FAILED';
            response.primaryMessage = '返品手続きを進めることができませんでした。お手数ですが、再度お試しください。';
            return response;
        }

        if (!(Boolean.TRUE.equals(evaluation.productFound) &&
              Boolean.TRUE.equals(evaluation.isReturnable) &&
              Boolean.TRUE.equals(evaluation.reasonAccepted))) {
            response.success = false;
            response.status = evaluation.status;
            response.primaryMessage = evaluation.primaryMessage;
            response.secondaryMessage = evaluation.secondaryMessage;
            return response;
        }

        FlowOutcome outcome = executeReturnOrderFlow(
            normalizedOrderNumber,
            normalizedProductCode,
            quantity,
            normalizedReturnReason
        );

        if (outcome.success) {
            response.success = true;
            response.status = 'RETURN_ORDER_CREATED';
            response.returnOrderNumber = outcome.returnOrderNumber;
            response.caseNumber = outcome.caseNumber;
            response.primaryMessage = buildSuccessMessage(outcome.returnOrderNumber);
            response.secondaryMessage = null;
        } else {
            response.success = false;
            response.status = 'RETURN_ORDER_FAILED';
            response.returnOrderNumber = null;
            response.caseNumber = null;
            response.primaryMessage = 'システムエラーにより返品手続きが完了しませんでした。お手数ですが、再度お試しください。';
            response.secondaryMessage = String.isBlank(outcome.errorMessage) ? null : outcome.errorMessage;
        }

        return response;
    }

    private static void validateInputs(String orderNumber, String productCode, Decimal quantity) {
        if (String.isBlank(orderNumber)) {
            throw new AuraHandledException('返品手続きを進めるには注文番号が必要です。');
        }

        if (String.isBlank(productCode)) {
            throw new AuraHandledException('返品手続きを進めるには商品コードが必要です。');
        }

        if (quantity == null || quantity <= 0) {
            throw new AuraHandledException('返品数量は1以上の数値を指定してください。');
        }
    }

    private static String buildSuccessMessage(String returnOrderNumber) {
        String number = String.isBlank(returnOrderNumber) ? '不明' : returnOrderNumber;
        return '返品手続きが完了しました。返品注文番号は『' + number + '』です。この番号をお控えください。担当者が確認次第、メールにてご連絡いたします。';
    }

    private static FlowOutcome executeReturnOrderFlow(String orderNumber,
                                                       String productCode,
                                                       Decimal quantity,
                                                       String returnReason) {
        FlowOutcome outcome = new FlowOutcome();
        Map<String, Object> inputs = new Map<String, Object>{
            'OrderNumber' => orderNumber,
            'ProductCode' => productCode,
            'Quantity' => quantity,
            'ReturnReason' => returnReason
        };

        try {
            Flow.Interview interview = Flow.Interview.createInterview('ReturnOrderFlow', inputs);
            interview.start();

            outcome.returnOrderNumber = (String) interview.getVariableValue('varReturnOrderNumber');
            outcome.caseNumber = (String) interview.getVariableValue('varCaseNumber');
            if (String.isBlank(outcome.returnOrderNumber)) {
                outcome.success = false;
                outcome.errorMessage = 'フローから返品注文番号が返されませんでした。';
            } else {
                outcome.success = true;
            }
        } catch (Exception e) {
            outcome.success = false;
            outcome.errorMessage = e != null ? e.getMessage() : null;
        }

        return outcome;
    }
}
