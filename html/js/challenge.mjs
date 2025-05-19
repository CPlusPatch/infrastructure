"use strict";

const progressIcon = document.getElementById("progress-icon");
const progressText = document.getElementById("progress-text");

/**
 * Solves the cryptographic challenge.
 * @param {number} difficulty - The difficulty level of the challenge.
 * @param {string} ip - The IP address of the user.
 * @param {string} timestamp - The timestamp of the challenge.
 * @return {Promise<number>} - The number of tries taken to solve the challenge.
 */
async function challenge(difficulty, ip, timestamp) {
    let encoder = new TextEncoder();
    let tries = 0;
    
    for (; tries < 10_000_000; tries++) {
        let hash = await crypto.subtle.digest(
            "SHA-256",
            encoder.encode([ip, location.hostname, timestamp, tries].join(";"))
        );
        let hashByteArray = new Uint8Array(hash);

        let i = 0;
        while (i < difficulty / 2) {
            if (hashByteArray[i] > 0x0f) break;
            if (i * 2 + 1 >= difficulty) return tries;
            if (hashByteArray[i++] > 0) break;
            if (i * 2 >= difficulty) return tries;
        }
    }
}

/**
 * Checks if the browser supports WebCrypto.
 * @throws {Error} - If WebCrypto is not supported or if the page is not served over HTTPS.
 */
async function checkCompatibility() {
    if (!("subtle" in window.crypto)) {
        if (location.protocol !== "https:") {
            throw new Error("No WebCrypto support. This must be served over a HTTPS connection.");
        } else {
            throw new Error("No WebCrypto support in your browser. This is required to pass the challenge.");
        }
    }
}

async function startChallenge(form) {
    try {
        await checkCompatibility();
    } catch (error) {
        setMessage("❌", error.message);
        return;
    }

    let backoff = 0;
    let tryOnce = (_) => {
        if (backoff > 8) {
            setMessage("❌", "Failed to submit after several tries. Try reloading.");
            return;
        }
        setTimeout(
            async (_) => submitAnswer(form),
            1000 * (Math.pow(2, backoff++) - 1)
        );
    };

    form.addEventListener("error", tryOnce);
    let iframe = document.querySelector("iframe");
    iframe.addEventListener("load", (_) =>
        location.hash.length ? location.reload() : location.replace(location)
    );
    tryOnce();
}

/**
 * Sets the message and icon for the progress bar.
 * @param {string} icon - The icon to display.
 * @param {string} message - The message to display.
 * @param {boolean} rotate - Whether to rotate the icon.
 */
function setMessage(icon, message, rotate = false) {
    progressIcon.innerText = icon;
    progressText.innerText = message;
    progressIcon.classList.toggle("rotate", rotate);
}

async function submitAnswer(form) {
    let start = new Date();
    ;
    let tries = await challenge(form.difficulty.value, form.ip.value, form.timestamp.value);

    if (tries === undefined) {
        setMessage("🤯", "Unable to calculate challenge. Try reloading or a different browser.");
        return;
    }
    form.tries.value = tries;

    setMessage("✅", `Took ${(new Date() - start)}ms.`);
    form.submit();
}

window.addEventListener("load", _ => startChallenge(document.forms.challenge));