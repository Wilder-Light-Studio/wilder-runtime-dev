package runtime

#RuntimeConfig: {
  mode: "development" | "debug" | "production"
  encryptionMode: *"standard" | "clear" | "standard" | "private" | "complete"
  recoveryEnabled: *false | bool
  operatorEscrow: *false | bool
  transport: "json" | "protobuf"
  logLevel: "trace" | "debug" | "info" | "warn" | "error"
  endpoint: string & != ""
  port: int & >=1 & <=65535
}

runtime: #RuntimeConfig
