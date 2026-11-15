'use strict';

const { Readable } = require('node:stream');
const { pipeline } = require('node:stream/promises');

async function streamMediaBody(body, response) {
  try {
    await pipeline(Readable.fromWeb(body), response);
  } catch (error) {
    if (error.code !== 'ERR_STREAM_PREMATURE_CLOSE') throw error;
  }
}

module.exports = { streamMediaBody };
