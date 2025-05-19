// @ts-check
"use strict";

// @ts-expect-error This is imported as text, not a module
import challengeWorkerCode from "./challenge-worker.mjs" with { type: "text" };

const progressIcon = document.getElementById("progress-icon");
const progressText = document.getElementById("progress-text");

/**
 * Creates a worker script blob for our worker threads
 * @returns {string} URL for the worker script
 */
function createWorkerScript() {
    const blob = new Blob([challengeWorkerCode], { type: 'application/javascript' });
    return URL.createObjectURL(blob);
}

/**
 * Solves the cryptographic challenge using Web Workers (one per CPU core).
 * @param {number} difficulty - The difficulty level of the challenge.
 * @param {string} ip - The IP address of the user.
 * @param {string} timestamp - The timestamp of the challenge.
 * @return {Promise<number | null>} - The number of tries taken to solve the challenge.
 */
async function challenge(difficulty, ip, timestamp) {
    // Determine number of CPU cores (use navigator.hardwareConcurrency or fallback to 4)
    const cpuCount = navigator.hardwareConcurrency || 4;
    const workerScript = createWorkerScript();
    const MAX_TRIES = 10_000_000;
    const chunkSize = Math.ceil(MAX_TRIES / cpuCount);
    
    return new Promise((resolve) => {
        let activeWorkers = 0;
        let workers = [];
        
        // Function to clean up workers when done
        const terminateWorkers = () => {
            for (const worker of workers) {
                if (worker) {
                    worker.terminate();
                }
            }

            URL.revokeObjectURL(workerScript);
        };
        
        // Create and start workers
        for (let i = 0; i < cpuCount; i++) {
            const startTries = i * chunkSize;
            const endTries = Math.min((i + 1) * chunkSize, MAX_TRIES);
            
            try {
                // Use import.meta.url so that the bundler can resolve the path correctly
                const worker = new Worker(workerScript);
                workers.push(worker);
                activeWorkers++;
                
                worker.onmessage = (e) => {
                    if (e.data.solved) {
                        terminateWorkers();
                        resolve(e.data.tries);
                    } else {
                        // This worker finished without finding a solution
                        activeWorkers--;
                        if (activeWorkers === 0) {
                            terminateWorkers();
                            resolve(null); // No solution found
                        }
                    }
                };
                
                worker.onerror = (err) => {
                    console.error('Worker error:', err);
                    activeWorkers--;

                    if (activeWorkers === 0) {
                        terminateWorkers();
                        resolve(null);
                    }
                };
                
                // Start the worker with its chunk of tries
                worker.postMessage({
                    difficulty,
                    ip,
                    hostname: location.hostname,
                    timestamp,
                    startTries,
                    endTries
                });
            } catch (error) {
                console.error('Error creating worker:', error);
                activeWorkers--;

                if (activeWorkers === 0) {
                    terminateWorkers();
                    resolve(null);
                }
            }
        }
    });
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
    
    if (!window.Worker) {
        throw new Error("Web Workers are not supported in this browser. This is required for parallel computation.");
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
    let tryOnce = () => {
        if (backoff > 8) {
            setMessage("❌", "Failed to submit after several tries. Try reloading.");
            return;
        }
        setTimeout(
            async () => submitAnswer(form),
            1000 * (Math.pow(2, backoff++) - 1)
        );
    };

    form.addEventListener("error", tryOnce);
    let iframe = document.querySelector("iframe");
    iframe?.addEventListener("load", () =>
        location.hash.length ? location.reload() : location.replace(location.href)
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
    if (!(progressIcon && progressText)) {
        console.error("Progress elements not found.");
        return;
    }

    progressIcon.innerText = icon;
    progressText.innerText = message;
    progressIcon.classList.toggle("rotate", rotate);
}

async function submitAnswer(form) {
    let start = Date.now();
    let tries = await challenge(form.difficulty.value, form.ip.value, form.timestamp.value);

    if (tries === null) {
        setMessage("🤯", "Unable to calculate challenge. Try reloading or a different browser.");
        return;
    }
    form.tries.value = tries;

    setMessage("✅", `Took ${(Date.now() - start)}ms.`);
    form.submit();
}

// @ts-expect-error the one piece is real!
window.addEventListener("load", () => startChallenge(document.forms.challenge));