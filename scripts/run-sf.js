const { existsSync } = require("node:fs");
const { delimiter, join } = require("node:path");
const { spawnSync } = require("node:child_process");

const args = process.argv.slice(2);

if (args.length === 0) {
  console.error("Usage: node scripts/run-sf.js <sf args...>");
  process.exit(1);
}

function isWindows() {
  return process.platform === "win32";
}

function pathEntries() {
  return (process.env.PATH || "")
    .split(delimiter)
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function unique(values) {
  return [...new Set(values)];
}

function candidateBins() {
  const bins = [];
  const programFiles = process.env.ProgramFiles || "C:\\Program Files";

  for (const entry of pathEntries()) {
    bins.push(join(entry, isWindows() ? "sf.cmd" : "sf"));
    bins.push(join(entry, isWindows() ? "sf.exe" : "sf"));
  }

  if (process.env.SF_BIN) {
    bins.unshift(process.env.SF_BIN);
  }

  if (isWindows()) {
    bins.push(join(programFiles, "sf", "bin", "sf.cmd"));
    bins.push(join(programFiles, "Salesforce CLI", "bin", "sf.cmd"));
    bins.push(join(programFiles, "sfdx", "bin", "sf.cmd"));
  } else {
    bins.push("/usr/local/bin/sf");
    bins.push("/opt/homebrew/bin/sf");
    bins.push("/usr/bin/sf");
  }

  return unique(bins);
}

function resolveSfBin() {
  return candidateBins().find((candidate) => existsSync(candidate));
}

function isLightningDevCommand(commandArgs) {
  return commandArgs[0] === "lightning" && commandArgs[1] === "dev";
}

function interruptedExitCode(result) {
  if (result.status === 130) {
    return 130;
  }

  if (result.signal === "SIGINT" || result.signal === "SIGBREAK") {
    return 130;
  }

  return null;
}

function stderrText(result) {
  if (!result.stderr) {
    return "";
  }

  return Buffer.isBuffer(result.stderr)
    ? result.stderr.toString("utf8")
    : String(result.stderr);
}

function stripOclifInterruptedExitStack(text) {
  return text.replace(
    /^[^\r\n]*@oclif[\\/].*?[\\/]errors[\\/]exit\.js:6\r?\n\s*throw new exit_1\.ExitError\(code\);\r?\n\s*\^\r?\n\r?\nExitError: EEXIT: 130[\s\S]*?\r?\n\}\r?\n?/m,
    ""
  );
}

const sfBin = resolveSfBin();

if (!sfBin) {
  console.error("Salesforce CLI (sf) was not found. Install it or set SF_BIN.");
  process.exit(1);
}

let result;
const lightningDev = isLightningDevCommand(args);
const stdio = lightningDev ? ["inherit", "inherit", "pipe"] : "inherit";

if (isWindows() && /\.cmd$/i.test(sfBin)) {
  const quoteForPowerShell = (arg) => `'${String(arg).replace(/'/g, "''")}'`;
  const command = `& ${quoteForPowerShell(sfBin)} ${args
    .map(quoteForPowerShell)
    .join(" ")}`;
  result = spawnSync(
    "powershell.exe",
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
    {
      stdio
    }
  );
} else {
  result = spawnSync(sfBin, args, { stdio });
}

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

const interruptedCode = interruptedExitCode(result);
const rawStderr = stderrText(result);

if (lightningDev && rawStderr) {
  const filteredStderr = stripOclifInterruptedExitStack(rawStderr);

  if (filteredStderr.trim()) {
    process.stderr.write(filteredStderr);
  }
} else if (rawStderr) {
  process.stderr.write(rawStderr);
}

if (lightningDev && interruptedCode === 130) {
  process.exit(0);
}

process.exit(result.status ?? 1);
