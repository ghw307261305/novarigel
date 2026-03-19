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

const sfBin = resolveSfBin();

if (!sfBin) {
  console.error("Salesforce CLI (sf) was not found. Install it or set SF_BIN.");
  process.exit(1);
}

let result;

if (isWindows() && /\.cmd$/i.test(sfBin)) {
  const quoteForPowerShell = (arg) => `'${String(arg).replace(/'/g, "''")}'`;
  const command = `& ${quoteForPowerShell(sfBin)} ${args
    .map(quoteForPowerShell)
    .join(" ")}`;
  result = spawnSync(
    "powershell.exe",
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
    {
      stdio: "inherit"
    }
  );
} else {
  result = spawnSync(sfBin, args, { stdio: "inherit" });
}

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

process.exit(result.status ?? 1);
