// @ts-check

/**
 * Solves the cryptographic challenge.
 * @param {number} startTries - The starting number of tries.
 * @param {number} endTries - The ending number of tries.
 * @param {number} difficulty - The difficulty level of the challenge.
 * @param {string} ip - The IP address of the user.
 * @param {string} hostname - The hostname of the server.
 * @param {string} timestamp - The timestamp of the challenge.
 * @return {Promise<number | null>} - The number of tries taken to solve the challenge. Null if not solved.
 */
async function challenge(startTries, endTries, difficulty, ip, hostname, timestamp) {
    let encoder = new TextEncoder();

    for (let tries = startTries; tries < endTries; tries++) {
        let hash = await crypto.subtle.digest(
            "SHA-256",
            encoder.encode([ip, hostname, timestamp, tries].join(";"))
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

    return null;
}

self.onmessage = async function (e) {
    const { difficulty, ip, timestamp, hostname, startTries, endTries } = e.data;

    console.info("Worker started!");
    const tries = await challenge(
        startTries,
        endTries,
        difficulty,
        ip,
        hostname,
        timestamp
    );
    console.info("Worker finished!", tries, "tries taken to solve the challenge.");

    if (tries === null) {
        self.postMessage({ solved: false });
        return;
    }

    // If the challenge is solved, send the result back to the main thread
    self.postMessage({ solved: true, tries });
}