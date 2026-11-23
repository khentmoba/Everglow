import { existsSync, readFileSync } from 'node:fs';
import { dirname, extname, resolve as resolvePath } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import ts from 'typescript';

export async function resolve(specifier, context, nextResolve) {
  if (specifier.startsWith('.') && !extname(specifier) && context.parentURL?.startsWith('file:') && context.parentURL.endsWith('.ts')) {
    const path = resolvePath(dirname(fileURLToPath(context.parentURL)), specifier);
    for (const extension of ['.ts', '.tsx', '.js', '.jsx']) {
      if (existsSync(path + extension)) return { url: pathToFileURL(path + extension).href, shortCircuit: true };
    }
  }
  return nextResolve(specifier, context);
}

export async function load(url, context, nextLoad) {
  if (url.startsWith('file:') && /\.tsx?$/.test(fileURLToPath(url))) {
    const path = fileURLToPath(url);
    const result = ts.transpileModule(readFileSync(path, 'utf8'), {
      fileName: path,
      compilerOptions: {
        jsx: ts.JsxEmit.ReactJSX,
        module: ts.ModuleKind.ESNext,
        target: ts.ScriptTarget.ES2022,
      },
    });
    return { format: 'module', source: result.outputText, shortCircuit: true };
  }
  return nextLoad(url, context);
}
