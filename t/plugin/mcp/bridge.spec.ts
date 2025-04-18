import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";
import { readFileSync } from "node:fs";
import { unlink, writeFile } from "node:fs/promises";
import path from "node:path";

const tools = JSON.parse(
  readFileSync(`./assets/bridge-list-tools.json`, "utf-8")
);
const sseEndpoint = new URL("http://localhost:1984/mcp/sse");

describe("mcp-bridge", () => {
  let client: Client;

  beforeEach(async () => {
    client = new Client({ name: "apisix-e2e-test", version: "1.0.0" });
    await expect(
      client.connect(new SSEClientTransport(sseEndpoint))
    ).resolves.not.toThrow();
  });

  afterEach(() => expect(client.close()).resolves.not.toThrow());

  it("should list tools", () =>
    expect(client.listTools()).resolves.toMatchObject(tools));

  it("should call tool", async () => {
    const result = await client.callTool({
      name: "list_directory",
      arguments: { path: "/" },
    });
    expect(result.content[0].text).toContain("[DIR] ");
  });

  it("should call both clients at the same time", async () => {
    // write test file
    await writeFile("/tmp/test.txt", "test file");

    // create client2
    const client2 = new Client({ name: "apisix-e2e-test", version: "1.0.0" });
    await expect(
      client2.connect(new SSEClientTransport(sseEndpoint))
    ).resolves.not.toThrow();

    // list tools both clients
    await expect(client.listTools()).resolves.toMatchObject(tools);
    await expect(client2.listTools()).resolves.toMatchObject(tools);

    // list directory both clients
    const result1 = await client.callTool({
      name: "list_directory",
      arguments: { path: "/" },
    });
    const result2 = await client2.callTool({
      name: "list_directory",
      arguments: { path: "/tmp" },
    });
    expect(result1.content[0].text).toContain("[DIR] home");
    expect(result2.content[0].text).toContain("[FILE] test.txt");

    // close client2
    await expect(client2.close()).resolves.not.toThrow();

    // remove test file
    await unlink("/tmp/test.txt");
  });
});
