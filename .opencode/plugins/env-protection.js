export const EnvProtection = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "read" && output.args.filePath && output.args.filePath.includes("env.txt")) {
        throw new Error("Do not read env.txt files");
      }
    },
  };
};
