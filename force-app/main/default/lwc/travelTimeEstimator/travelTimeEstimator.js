import { LightningElement, api } from "lwc";
import getTravelTimes from "@salesforce/apex/TravelTimeController.getTravelTimes";

const MODE_LABELS = {
  driving: "車での移動",
  walking: "徒歩",
  transit: "公共交通機関",
  transit_mixed: "公共交通機関＋徒歩"
};

export default class TravelTimeEstimator extends LightningElement {
  @api cardTitle = "Google 経路時間検索";

  origin = "";
  destination = "";
  results = [];
  error;
  isLoading = false;

  get hasResults() {
    return Array.isArray(this.results) && this.results.length > 0;
  }

  handleOriginChange(event) {
    this.origin = event.target.value;
  }

  handleDestinationChange(event) {
    this.destination = event.target.value;
  }

  async handleCalculate() {
    this.error = undefined;
    this.results = [];

    if (!this.origin || !this.destination) {
      this.error = "出発地と到着地を入力してください。";
      return;
    }

    this.isLoading = true;

    try {
      const apiResults = await getTravelTimes({
        origin: this.origin,
        destination: this.destination
      });
      this.results = (apiResults || []).map((item) => ({
        ...item,
        modeLabel: MODE_LABELS[item.mode] || item.mode,
        isSuccess: item.status === "OK"
      }));

      if (!this.results.length) {
        this.error =
          "経路情報を取得できませんでした。しばらくしてから再度お試しください。";
      }
    } catch (err) {
      this.error = this.normalizeError(err);
    } finally {
      this.isLoading = false;
    }
  }

  normalizeError(err) {
    if (!err) {
      return "不明なエラーが発生しました。";
    }

    if (Array.isArray(err.body)) {
      return err.body.map((e) => e.message).join(", ");
    }

    if (err.body && typeof err.body.message === "string") {
      return err.body.message;
    }

    if (typeof err.message === "string") {
      return err.message;
    }

    return "不明なエラーが発生しました。";
  }
}
