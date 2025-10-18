/**
 * @description       : 注文情報と注文商品の内容をフォーマット済みテキストとして返す（店舗ポリシー連携・返品可否付き）
 * @author            : NovaRigel
 * @last modified on  : 10-18-2025
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

    @InvocableMethod(label='注文情報フォーマット出力（店舗ポリシー付き）' description='注文番号に基づいて注文情報を取得し、店舗ポリシーを考慮した返品可否情報を含むテキストを返します。')
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
                // 注文情報の取得
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

                // 注文商品の取得
                List<OrderItem> items = [
                    SELECT Id, Quantity, UnitPrice, Product2Id, Product2.Name, Product2.ProductCode
                    FROM OrderItem
                    WHERE OrderId = :ord.Id
                ];

                // 商品IDリスト作成
                Set<Id> productIds = new Set<Id>();
                for (OrderItem oi : items) {
                    if (oi.Product2Id != null) productIds.add(oi.Product2Id);
                }

                // 店舗ポリシー商品関連＋店舗ポリシー情報取得
                Map<Id, StorePolicyProduct__c> productPolicyMap = new Map<Id, StorePolicyProduct__c>();
                if (!productIds.isEmpty()) {
                    for (StorePolicyProduct__c spp : [
                        SELECT Id, Product__c, StorePolicy__c, IsActive__c, Remarks__c,
                               StorePolicy__r.Name,
                               StorePolicy__r.PolicyType__c,
                               StorePolicy__r.IsActive__c,
                               StorePolicy__r.ValidFrom__c,
                               StorePolicy__r.ValidTo__c,
                               StorePolicy__r.Description__c
                        FROM StorePolicyProduct__c
                        WHERE Product__c IN :productIds
                    ]) {
                        productPolicyMap.put(spp.Product__c, spp);
                    }
                }

                // --- テキスト組み立て ---
                String formatted = '';
                formatted += '注文日: ' + (ord.EffectiveDate != null ? ord.EffectiveDate.format() : '不明') + '\n';
                formatted += '購入者: ' + (ord.Account != null ? ord.Account.Name : '不明') + '\n';
                formatted += '合計金額: ¥' + (ord.TotalAmount != null ? String.valueOf(ord.TotalAmount.intValue()) : '0') + '\n';
                formatted += '商品詳細:\n';

                Integer index = 1;
                Date today = System.today();

                for (OrderItem oi : items) {
                    formatted += index + '. 商品名: ' + (oi.Product2 != null ? oi.Product2.Name : '不明');
                    formatted += ' / 商品コード: ' + (oi.Product2 != null && oi.Product2.ProductCode != null ? oi.Product2.ProductCode : '不明');
                    formatted += ' / 単価: ¥' + (oi.UnitPrice != null ? String.valueOf(oi.UnitPrice.intValue()) : '0');
                    formatted += ' / 数量: ' + (oi.Quantity != null ? String.valueOf(oi.Quantity.intValue()) : '0');

                    // 店舗ポリシー判定
                    if (oi.Product2Id != null && productPolicyMap.containsKey(oi.Product2Id)) {
                        StorePolicyProduct__c spp = productPolicyMap.get(oi.Product2Id);
                        StorePolicy__c sp = spp.StorePolicy__r;

                        Boolean policyActive = (spp.IsActive__c == true) && (sp != null && sp.IsActive__c == true);
                        Boolean dateValid = (sp.ValidFrom__c == null || sp.ValidFrom__c <= today) &&
                                            (sp.ValidTo__c == null || sp.ValidTo__c >= today);

                        if (policyActive && dateValid) {
                            formatted += ' / 返品可否: 可（ポリシー名: ' + sp.Name + '）';
                        } else {
                            String reason = '';
                            if (!policyActive) {
                                reason = 'ポリシーが無効または停止中';
                            } else if (!dateValid) {
                                reason = '有効期間外（' + 
                                         (sp.ValidFrom__c != null ? sp.ValidFrom__c.format() : '不明') + '〜' +
                                         (sp.ValidTo__c != null ? sp.ValidTo__c.format() : '不明') + '）';
                            } else {
                                reason = '不明な理由';
                            }
                            formatted += ' / 返品可否: 不可（理由: ' + reason + '）';
                        }

                        if (sp.Description__c != null) {
                            formatted += '\n　ポリシー説明: ' + sp.Description__c;
                        }
                        if (spp.Remarks__c != null) {
                            formatted += '\n　備考: ' + spp.Remarks__c;
                        }

                    } else {
                        formatted += ' / 返品可否: 不明（店舗ポリシーが設定されていません）';
                    }

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
