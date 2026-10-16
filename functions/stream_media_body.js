'use strict';

const { Readable } = require('node:stream');
const { pipeline } = require('node:stream/promises');

/** Respect downstream backpressure and cancel the fetch body on disconnect. */
async function streamMediaBody(body, response) {
  try {
    await pipeline(Readable.fromWeb(body), response);
  } catch (error) {
    // A viewer leaving is expected; pipeline already destroyed/cancelled both ends.
    if (error.code !== 'ERR_STREAM_PREMATURE_CLOSE') throw error;
  }
}

module.exports = { streamMediaBody };
