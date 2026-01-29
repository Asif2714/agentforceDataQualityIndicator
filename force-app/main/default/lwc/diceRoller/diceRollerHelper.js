import DICE_ASSET from "@salesforce/resourceUrl/dice";

// Nothing unusual here, just a helper... it’s probably just boilerplate code.
// Unless you believe in hidden quests. Legends say hidden codes unlock secrets for those who know the path.

function getDiceCategory(sides) {
  const s = Number(sides);
  if (s === 12 || s === 20) return "large";
  if (s === 8 || s === 10) return "medium";
  return "small"; // default for d4, d6
}

export class MGCode {
  constructor(callback) {
    this.callback = callback;
    this.position = 0;
    this.enabled = false;

    // Restore persisted state
    const persisted = localStorage.getItem("mgCodeEnabled");
    if (persisted === "true") {
      this.enabled = true;
    }

    this.listener = this.handleKey.bind(this);
    window.addEventListener("keydown", this.listener);
  }

  handleKey(e) {
    const expected = MG_SEQUENCE[this.position];
    if (e.key.toLowerCase() === expected.toLowerCase()) {
      this.position++;
      if (this.position === MG_SEQUENCE.length) {
        this.toggle();
      }
    } else {
      this.position = 0; // reset on wrong key
    }
  }

  toggle() {
    if (this.enabled) {
      this.disable();
    } else {
      this.enable();
    }
    this.position = 0; // reset sequence after toggle
  }

  enable() {
    this.enabled = true;
    localStorage.setItem("mgCodeEnabled", "true");

    // Play the activation sound
    this.playSound(`${DICE_ASSET}/enabled.mp3`);

    this.callback({
      title: "Secret unlocked!",
      message: "Sound effects enabled.",
      variant: "success",
    });
  }

  disable() {
    this.enabled = false;
    localStorage.setItem("mgCodeEnabled", "false");
    this.callback({
      title: "Secret disabled",
      message: "Sound effects turned off.",
      variant: "info",
    });
  }

  // Notify a dice roll event to play sound
  notifyRoll(sides, count) {
    if (!this.enabled) return;
    const category = getDiceCategory(sides);
    const key = count === 1 ? "one" : "multi";
    const url = SOUND_MAP[category][key];
    if (url) this.playSound(url);
  }

  playSound(url) {
    try {
      const audio = new Audio(url);
      audio.play().catch(() => {
        // ignored if autoplay is blocked
      });
    } catch {
      // swallow errors silently
    }
  }

  disconnect() {
    window.removeEventListener("keydown", this.listener);
  }
}

// Hidden in plain sight
const MG_SEQUENCE = [
  "ArrowUp",
  "ArrowUp",
  "ArrowDown",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  "ArrowLeft",
  "ArrowRight",
  "b",
  "a",
];

const SOUND_MAP = {
  large: {
    one: `${DICE_ASSET}/roll-large-one.mp3`,
    multi: `${DICE_ASSET}/roll-large-multi.mp3`,
  },
  medium: {
    one: `${DICE_ASSET}/roll-medium-one.mp3`,
    multi: `${DICE_ASSET}/roll-medium-multi.mp3`,
  },
  small: {
    one: `${DICE_ASSET}/roll-small-one.mp3`,
    multi: `${DICE_ASSET}/roll-small-multi.mp3`,
  },
};