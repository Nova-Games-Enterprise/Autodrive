let showing = false;

const bodyElem = document.body;
const canvas1 = document.getElementById("canvas");
const canvas2 = document.getElementById("canvas2");

const ctx1 = canvas1.getContext("2d");
const ctx2 = canvas2.getContext("2d");

const hudAp = document.getElementById("hud-ap");
const hudSafety = document.getElementById("hud-safety");
const hudSpeed = document.getElementById("hud-speed");

window.addEventListener("message", (event) => {
    const data = event.data;

    if (data.type === "ui") {
        showing = data.status === true;
        bodyElem.style.display = showing ? "block" : "none";
        if (!showing) {
            clearLines();
        }
    }

    if (data.type === "angleinfo") {
        if (!showing) return;
        const angle = Number(data.angle) || 0;
        drawGuideLines(angle);
    }

    if (data.type === "hud") {
        updateHud(data);
    }
});

function clearLines() {
    ctx1.clearRect(0, 0, canvas1.width, canvas1.height);
    ctx2.clearRect(0, 0, canvas2.width, canvas2.height);
}

function drawGuideLines(angle) {
    clearLines();

    const maxAngle = 40;
    const clampedAngle = Math.max(Math.min(angle, maxAngle), -maxAngle);
    const factor = clampedAngle / maxAngle;

    const midX = canvas1.width / 2;
    const startY = canvas1.height * 0.1;
    const endY = canvas1.height * 0.9;

    const spread = canvas1.width * 0.12;
    const curve = canvas1.width * 0.25 * factor;

    // linea sinistra
    ctx1.beginPath();
    ctx1.moveTo(midX - spread, startY);
    ctx1.quadraticCurveTo(
        midX - spread - curve,
        (startY + endY) / 2,
        midX - spread,
        endY
    );
    ctx1.strokeStyle = "#e6e6e6";
    ctx1.lineWidth = 7;
    ctx1.stroke();

    // linea destra
    ctx2.beginPath();
    ctx2.moveTo(midX + spread, startY);
    ctx2.quadraticCurveTo(
        midX + spread - curve,
        (startY + endY) / 2,
        midX + spread,
        endY
    );
    ctx2.strokeStyle = "#e6e6e6";
    ctx2.lineWidth = 7;
    ctx2.stroke();
}

function updateHud(data) {
    if (typeof data.autopilot !== "undefined") {
        hudAp.textContent = data.autopilot ? "AP: ON" : "AP: OFF";
    }

    if (typeof data.cruiseSpeed !== "undefined") {
        const spd = Math.round(Number(data.cruiseSpeed) || 0);
        hudSpeed.textContent = "SPD: " + spd;
    }

    if (typeof data.safety !== "undefined") {
        let state = String(data.safety || "off");

        hudSafety.classList.remove("hud-safe", "hud-warning", "hud-brake");

        if (state === "off") {
            hudSafety.textContent = "SAFETY: OFF";
        } else if (state === "normal") {
            hudSafety.textContent = "SAFETY: ON";
            hudSafety.classList.add("hud-safe");
        } else if (state === "warning") {
            hudSafety.textContent = "SAFETY: WARNING";
            hudSafety.classList.add("hud-warning");
        } else if (state === "brake") {
            hudSafety.textContent = "SAFETY: BRAKE";
            hudSafety.classList.add("hud-brake");
        } else {
            hudSafety.textContent = "SAFETY: " + state.toUpperCase();
        }
    }
}
