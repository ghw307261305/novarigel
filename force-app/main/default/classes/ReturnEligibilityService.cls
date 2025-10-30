/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 10-18-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class ReturnEligibilityService {
  public class EvaluationInput {
    @InvocableVariable(required=true)
    public String productIdentifier;

    @InvocableVariable
    public String returnReason;
  }

  public class EvaluationResult {
    // 提供された識別子に一致する商品が見つかったかどうかを示します。
    @AuraEnabled
    @InvocableVariable
    public Boolean productFound;

    // 対象商品のID。後続のフローで商品情報を参照する際に利用します。
    @AuraEnabled
    @InvocableVariable
    public Id productId;

    // 対象商品の名称です。
    @AuraEnabled
    @InvocableVariable
    public String productName;

    // 対象商品の商品コード／SKUです。
    @AuraEnabled
    @InvocableVariable
    public String productCode;

    // 対象商品の製品ファミリーです。
    @AuraEnabled
    @InvocableVariable
    public String productFamily;

    // 対象商品の説明文です。
    @AuraEnabled
    @InvocableVariable
    public String productDescription;

    // 標準価格表に登録されている単価です。
    @AuraEnabled
    @InvocableVariable
    public Decimal productUnitPrice;

    // 続行前に顧客へ返品理由の確認が必要かどうかを示します。
    @AuraEnabled
    @InvocableVariable
    public Boolean requiresReason;

    // 設定されたポリシーの下で現在返品可能かどうかを表します。
    @AuraEnabled
    @InvocableVariable
    public Boolean isReturnable;

    // 入力された返品理由がポリシー条件を満たしているかを記録します。
    @AuraEnabled
    @InvocableVariable
    public Boolean reasonAccepted;

    // 顧客の自由入力から判定した返品理由カテゴリを保持します。
    @AuraEnabled
    @InvocableVariable
    public String reasonCategory;

    // 本商品の返品対応に適用された店舗ポリシー名です。
    @AuraEnabled
    @InvocableVariable
    public String policyName;

    // 適用された店舗ポリシーのIDです。
    @AuraEnabled
    @InvocableVariable
    public Id policyId;

    // 商品別ポリシー設定のIDです。
    @AuraEnabled
    @InvocableVariable
    public Id policyProductId;

    // 適用されたポリシーの種別（標準・キャンペーンなど）を示します。
    @AuraEnabled
    @InvocableVariable
    public String policyType;

    // 今回適用した返品ポリシーの説明文です。
    @AuraEnabled
    @InvocableVariable
    public String policyDescription;

    // 評価結果に応じて顧客へ伝えるメインメッセージです。
    @AuraEnabled
    @InvocableVariable
    public String primaryMessage;

    // メインメッセージを補足する追記・案内メッセージです。
    @AuraEnabled
    @InvocableVariable
    public String secondaryMessage;

    // 交換対応が可能な場合に提示する案内メッセージです。
    @AuraEnabled
    @InvocableVariable
    public String exchangeMessage;

    // 在庫があり交換候補となる関連バリエーションの一覧です。
    @AuraEnabled
    public List<ProductSuggestion> exchangeOptions;

    // 類似特性や価格帯を持つ代替商品の推奨リストです。
    @AuraEnabled
    public List<ProductSuggestion> alternativeProducts;

    // 提案した代替商品をまとめて案内するメッセージです。
    @AuraEnabled
    @InvocableVariable
    public String alternativeMessage;

    // 評価処理の状態（未解決・理由待ち・承認・却下など）を表します。
    @AuraEnabled
    @InvocableVariable
    public String status;

    // ユーザーが選択可能な返品理由カテゴリ一覧です。
    @AuraEnabled
    @InvocableVariable
    public List<String> availableReasonCategories;

    public EvaluationResult() {
      this.exchangeOptions = new List<ProductSuggestion>();
      this.alternativeProducts = new List<ProductSuggestion>();
      this.availableReasonCategories = new List<String>();
    }
  }

  public class ProductSuggestion {
    // 推奨商品のIDで、後続処理（発送指示など）で利用します。
    @AuraEnabled
    public Id productId;

    // 推奨商品の表示名です。
    @AuraEnabled
    public String name;

    // 推奨商品の商品コード／SKUです。
    @AuraEnabled
    public String productCode;

    // 価格比較に用いる現在の単価です。
    @AuraEnabled
    public Decimal unitPrice;

    // 商品カテゴリの把握に役立つ製品ファミリー名です。
    @AuraEnabled
    public String family;

    // 推奨商品の補足説明です。
    @AuraEnabled
    public String description;
  }

  @AuraEnabled
  public static EvaluationResult evaluateProductReturn(
    String productIdentifier,
    String returnReason
  ) {
    return handleEvaluation(productIdentifier, returnReason);
  }

  @InvocableMethod(
    label='返品ポリシー判定'
    description='商品名または商品コードと返品理由に基づいて返品可否を判定し、適切なガイダンスを返します。'
  )
  public static List<EvaluationResult> evaluate(List<EvaluationInput> inputs) {
    List<EvaluationResult> results = new List<EvaluationResult>();
    for (EvaluationInput input : inputs) {
      results.add(
        handleEvaluation(
          input != null ? input.productIdentifier : null,
          input != null ? input.returnReason : null
        )
      );
    }
    return results;
  }

  private static EvaluationResult handleEvaluation(
    String productIdentifier,
    String returnReason
  ) {
    ReturnProductEligibilityService.ProductEvaluation productEvaluation = ReturnProductEligibilityService.evaluate(
      productIdentifier
    );

    if (productEvaluation == null) {
      return new EvaluationResult();
    }

    EvaluationResult result = productEvaluation.result;
    if (result == null) {
      result = new EvaluationResult();
    }

    if (!Boolean.TRUE.equals(productEvaluation.canProceed)) {
      return result;
    }

    return ReturnReasonEvaluationService.evaluate(
      returnReason,
      productEvaluation.policy,
      result,
      productEvaluation.product
    );
  }
}
