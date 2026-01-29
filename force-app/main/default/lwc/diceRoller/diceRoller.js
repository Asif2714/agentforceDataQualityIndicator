// Lightning Web Component for interactive dice rolling interface
import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { MGCode } from "./diceRollerHelper";
import USER_ID from "@salesforce/user/Id";
import rollAndSave from "@salesforce/apex/DiceRollService.rollAndSave";
import getActiveUsers from "@salesforce/apex/DiceRollService.getActiveUsers";
import DICE_ASSET from "@salesforce/resourceUrl/dice";

// Available die types and quick roll options
const DICE = ["4", "6", "8", "10", "12", "20"];
const QUICK = [1, 2, 3, 4, 5, 6];

export default class DiceRoller extends LightningElement {
  // Roll configuration properties
  modifierText = "0";
  modifier = 0;
  rollerId = USER_ID;

  // UI state management
  userOptions = [];
  loading = false;
  error = "";

  // Internal variable to hold tile results
  @track tileResults = {};

  // Initialize component and load user options
  connectedCallback() {
    this.loadUsers();
  }

  // Modifier adjustment methods
  incrementModifier() {
    const current = parseInt(this.modifierText || "0", 10) || 0;
    this.modifierText = String(current + 1);
    this.modifier = current + 1;
  }

  decrementModifier() {
    const current = parseInt(this.modifierText || "0", 10) || 0;
    this.modifierText = String(current - 1);
    this.modifier = current - 1;
  }

  // Load active users for roller selection
  async loadUsers() {
    try {
      const opts = await getActiveUsers({ limitSize: 100 });
      if (!opts.some((o) => o.value === this.rollerId)) {
        opts.unshift({ label: "Me", value: this.rollerId });
      }
      this.userOptions = opts;
    } catch {
      this.userOptions = [{ label: "Me", value: this.rollerId }];
    }
  }

  // Generate die icon paths with SVG/PNG fallback
  iconPaths(s) {
    return {
      svg: `${DICE_ASSET}/d${s}.svg`,
      png: `${DICE_ASSET}/d${s}.png`,
      alt: `D${s} icon`,
    };
  }

  // Build tile data for each die type
  get tiles() {
    return DICE.map((s) => {
      const p = this.iconPaths(s);
      return {
        sides: s,
        label: `D${s}`,
        iconSrc: p.svg,
        iconFallback: p.png,
        alt: p.alt,
        quick: QUICK.map((n) => ({ count: n, label: `${n} D${s}` })),
        last: this.tileResults[s] || null,
      };
    });
  }

  // Handle image load errors by switching to fallback format
  handleIconError(evt) {
    const img = evt.target;
    const fallback = img?.dataset?.fallbackSrc;
    if (fallback && img.src !== fallback) {
      img.src = fallback;
    }
  }

  // Error and input handling methods
  clearError() {
    this.error = "";
  }

  handleRoller(e) {
    this.rollerId = e.detail.value;
    this.clearError();
  }

  // Restrict modifier input to integers only
  onlyIntegerKeyDown(e) {
    const ok = [
      "Backspace",
      "Delete",
      "ArrowLeft",
      "ArrowRight",
      "Tab",
      "Home",
      "End",
    ];
    if (ok.includes(e.key)) return;
    if (e.key === "-") {
      const val = e.target.value || "";
      if (e.target.selectionStart !== 0 || val.includes("-"))
        e.preventDefault();
      return;
    }
    if (!/^\d$/.test(e.key)) e.preventDefault();
  }

  // Validate pasted content for modifier field
  handleModifierPaste(e) {
    const t = (e.clipboardData || window.clipboardData).getData("text");
    if (!/^-?\d+$/.test(t)) e.preventDefault();
  }

  // Clean and validate modifier input
  handleModifierChange(e) {
    let v = e.detail.value || "";
    v = v.replace(/[^\d-]/g, "").replace(/(?!^)-/g, "");
    if (v.includes("-")) v = "-" + v.replace(/-/g, "");
    if (v === "" || v === "-") v = "0";
    this.modifierText = v;
    this.modifier = parseInt(v, 10);
    this.clearError();
  }

  handleModifierBlur() {
    if (this.modifierText === "" || this.modifierText === "-") {
      this.modifierText = "0";
      this.modifier = 0;
    }
  }

  // Handle quick roll button clicks
  async handleQuickRoll(e) {
    const sides = Number(e.currentTarget.dataset.sides);
    const count = Number(e.currentTarget.dataset.count);

    // Validate inputs before rolling
    if (
      !/^(-?\d+)$/.test(this.modifierText) ||
      this.modifier < -99 ||
      this.modifier > 99
    ) {
      return this.toast(
        "Invalid modifier",
        "Modifier must be an integer between -99 and 99.",
        "error"
      );
    }
    if (!this.rollerId) {
      return this.toast("Missing roller", "Select a roller.", "error");
    }

    try {
      this.loading = true;

      // Notify roll
      this.ee.notifyRoll(sides, count);

      const res = await rollAndSave({
        numberOfDice: count,
        sides,
        modifier: this.modifier,
        rollerId: this.rollerId,
      });

      // Process and store roll results
      const cleanNotation = this.buildNotation(count, sides, this.modifier);

      this.tileResults = {
        ...this.tileResults,
        [String(sides)]: {
          notation: cleanNotation,
          total: res.total,
          hadCritical: !!res.hadCritical,
          diceValuesText: this.toDiceValuesText(res.resultsJson),
        },
      };

      this.toast(
        "Roll saved",
        `${res.notation} = ${res.total}${res.hadCritical ? " critical" : ""}`,
        "success"
      );
    } catch (e2) {
      const msg = e2?.body?.message || "Unexpected error";
      this.toast("Roll failed", msg, "error");
    } finally {
      this.loading = false;
    }

    return undefined; // Ensures consistent return type
  }

  // Generate clean dice notation string
  buildNotation(count, sides, modifier) {
    const m = Number.isFinite(modifier) ? modifier : 0;
    return `${count}d${sides}${m === 0 ? "" : m > 0 ? `+${m}` : `${m}`}`;
  }

  ee;
  connectedCallback() {
    this.loadUsers();
    this.ee = new MGCode((msg) => {
      this.toast(msg.title, msg.message, msg.variant);
    });
  }

  disconnectedCallback() {
    if (this.ee) this.ee.disconnect();
  }

  // Convert JSON dice results to display text
  toDiceValuesText(json) {
    try {
      const arr = JSON.parse(json);
      return Array.isArray(arr) ? arr.join(", ") : json;
    } catch {
      return json;
    }
  }

  // Display toast notification
  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  get footerSrc() {
    return `${DICE_ASSET}/footer_sf.png`;
  }
}