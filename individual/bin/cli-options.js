const { execSync } = require("child_process");
const commandLineArgs = require("command-line-args");
const commandlineUsage = require("command-line-usage");

const thisOrigin = execSync("git remote get-url origin")
  .toString()
  .match(/:(.+)\./)[1];

const optionDefinitions = [
  {
    name: "disk-size",
    alias: "d",
    type: Number,
    required: true,
    defaultValue: 50,
    description: "EBS block storage to allocate (minimum: 8)",
  },
  {
    name: "email",
    alias: "e",
    type: String,
    required: true,
    description: "Environment owner's @northwestern.edu email address",
  },
  {
    name: "github-id",
    alias: "g",
    type: String,
    required: true,
    description: "GitHub ID of environment owner",
  },
  {
    name: "git-ref",
    type: String,
    required: true,
    defaultValue: "main",
    description: "Ref (branch/tag/sha) to pull init scripts from",
  },
  {
    name: "git-repo",
    type: String,
    required: true,
    defaultValue: thisOrigin,
    description: "GitHub repository to pull init scripts from",
  },
  {
    name: "instance-type",
    alias: "t",
    type: String,
    required: true,
    defaultValue: "t3.large",
    description: "EC2 instance type",
  },
  {
    name: "net-id",
    alias: "n",
    type: String,
    required: true,
    description: "NetID of environment owner",
  },
  {
    name: "shutdown-minutes",
    alias: "s",
    type: Number,
    required: true,
    defaultValue: 30,
    description: "Number of minutes before environment hibernates (minimum: 5)",
  },
  {
    name: "help",
    alias: "h",
    type: Boolean,
    required: false,
    defaultValue: false,
    description: "Show this help message",
  },
];

const camelize = (arg) => {
  switch (typeof arg) {
    case "string":
      return arg.replace(/-([a-z])/g, (g) => g[1].toUpperCase());
    case "object":
      return Object.keys(arg).reduce((result, key) => {
        result[camelize(key)] = arg[key];
        return result;
      }, {});
    default:
      return arg;
  }
};

const context = camelize(commandLineArgs(optionDefinitions));

if (process.env.SHOW_AND_QUIT) {
  console.log(context);
  process.exit(0);
}

function validateOpts(opts) {
  const required = optionDefinitions
    .filter((opt) => opt.required)
    .map((opt) => camelize(opt.name));

  if (required.find((v) => opts[v] === undefined)) return false;
  if (isNaN(opts.diskSize) || opts.diskSize < 8) return false;
  if (isNaN(opts.shutdownMinutes) || opts.shutdownMinutes < 5) return false;
  return true;
}

if (context.help || !validateOpts(context)) {
  const usage = commandlineUsage([
    {
      header: "Usage",
      optionList: optionDefinitions,
    },
  ]);
  console.log(usage);
  process.exit(1);
}

module.exports = context;
