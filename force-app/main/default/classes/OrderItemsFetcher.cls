/**
 * @description       : 注文情報と注文商品の内容をフォーマット済みテキストとして返す（商品コード付き）
 * @author            : NovaRigel
 * @last modified on  : 10-15-2025
 */
public with sharing class OrderItemsFetcher {

    public class Request {
        @InvocableVariable(required=true)
        public String orderNumber;
    }

    public class Response {
        @InvocableVariable
        public String formattedText;
    }

    /**
     * 指定された注文番号に基づき、注文情報と注文商品の内容をフォーマット済みテキストとして返す
     */
    @InvocableMethod(label='注文情報フォーマット出力' description='注文番号に基づいて注文情報を取得し、整形されたテキストを返します。')
    public static List<Response> getFormattedOrderSummary(List<Request> requests) {
        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();

            if (String.isBlank(req.orderNumber)) {
                res.formattedText = '注文番号が指定されていません。';
                results.add(res);
                continue;
            }

            try {
                // 注文情報の取得（存在しない場合に備えてListで取得）
                List<Order> orders = [
                    SELECT Id, Name, EffectiveDate, Account.Name, TotalAmount
                    FROM Order
                    WHERE OrderNumber = :req.orderNumber
                    LIMIT 1
                ];

                if (orders.isEmpty()) {
                    res.formattedText = '注文情報が存在しません。正しい注文番号を入力してください。';
                    results.add(res);
                    continue;
                }

                Order ord = orders[0];

                // 注文商品の取得（商品コードを含む）
                List<OrderItem> items = [
                    SELECT Id, Quantity, UnitPrice, Product2.Name, Product2.ProductCode
                    FROM OrderItem
                    WHERE OrderId = :ord.Id
                ];

                // --- テキスト組み立て ---
                String formatted = '';
                formatted += '注文日: ' + (ord.EffectiveDate != null ? ord.EffectiveDate.format() : '不明') + '\n';
                formatted += '購入者: ' + (ord.Account != null ? ord.Account.Name : '不明') + '\n';
                formatted += '合計金額: ¥' + (ord.TotalAmount != null ? String.valueOf(ord.TotalAmount.intValue()) : '0') + '\n';
                formatted += '商品詳細:\n';

                Integer index = 1;
                for (OrderItem oi : items) {
                    formatted += index + '. 商品名: ' + (oi.Product2 != null ? oi.Product2.Name : '不明');
                    formatted += ' / 商品コード: ' + (oi.Product2 != null && oi.Product2.ProductCode != null ? oi.Product2.ProductCode : '不明');
                    formatted += ' / 単価: ¥' + (oi.UnitPrice != null ? String.valueOf(oi.UnitPrice.intValue()) : '0');
                    formatted += ' / 数量: ' + (oi.Quantity != null ? String.valueOf(oi.Quantity.intValue()) : '0');
                    formatted += '\n';
                    index++;
                }

                res.formattedText = formatted;

            } catch (Exception e) {
                res.formattedText = '注文情報の取得中にエラーが発生しました: ' + e.getMessage();
            }

            results.add(res);
        }

        return results;
    }
}