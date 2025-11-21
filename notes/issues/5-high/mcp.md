# Adding MCP to the chat service
TODO: I am just jotting this down. need to update b4 this issue is ready to assign

https://chatgpt.com/g/g-p-691e260ebb3c819196fe4147dbfa7787/c/691e284a-8678-8327-b9f6-2a5ff05d5cd4

Yeah, this is the key missing piece: models don’t “see” MCP directly. There’s always a client/orchestrator in the middle that:
- Connects to MCP servers (Mongo MCP, Pinecone MCP, etc.).
- Describes those tools to the LLM.
- Parses the LLM’s “tool call” decision.
- Calls the MCP tool.
- Feeds results back to the LLM.

```py
# qwen_mcp_agent.py
import json
import asyncio
from transformers import AutoTokenizer, AutoModelForCausalLM, pipeline

from mcp import ClientSession   # actual import names may differ; check mcp docs
from mcp.client.stdio import StdioServer

# 1) Load Qwen locally (CPU)
tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen3-4B-Thinking-2507")
model = AutoModelForCausalLM.from_pretrained("Qwen/Qwen3-4B-Thinking-2507")
llm = pipeline("text-generation", model=model, tokenizer=tokenizer, device=-1)

# 2) Connect to an MCP server (e.g. Mongo MCP) via stdio
async def connect_mongo_mcp() -> ClientSession:
    server = StdioServer(
        name="mongo-mcp",
        command=["node", "/path/to/mongo-mcp-server.js"],  # or python script
    )
    session = ClientSession(server)
    await session.start()
    return session

# 3) One-step agent loop: ask Qwen if it wants to call a tool
SYSTEM_PROMPT = """You can answer directly, or call a tool.

Tools are JSON objects of this form:
{"action": "tool_call", "tool": "mongo.search", "arguments": {...}}

If you want to answer directly:
{"action": "final_answer", "content": "..."}

Only output ONE valid JSON object and nothing else.
"""

def call_qwen(messages):
    # very barebones; you’ll want proper chat formatting
    prompt = "\n".join(f"{m['role'].upper()}: {m['content']}" for m in messages)
    out = llm(prompt, max_new_tokens=512)[0]["generated_text"]
    # assume last JSON block is the decision; you’d tighten this in real code
    json_start = out.rfind("{")
    return json.loads(out[json_start:])

async def handle_query_with_mcp(user_query: str):
    session = await connect_mongo_mcp()

    # Discover tools (you might use this to build the prompt dynamically)
    tools = await session.list_tools()

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_query},
        # You might also inject a short tool description here based on `tools`
    ]

    decision = call_qwen(messages)

    if decision["action"] == "final_answer":
        await session.close()
        return decision["content"]

    if decision["action"] == "tool_call":
        tool_name = decision["tool"]          # e.g. "mongo.search"
        args = decision.get("arguments", {})

        tool_result = await session.call_tool(tool_name, args)

        # Now ask Qwen again, with tool result
        messages.append({
            "role": "assistant",
            "content": f"TOOL RESULT:\n{tool_result}"
        })
        messages.append({
            "role": "user",
            "content": "Using this result, answer the original question."
        })

        final = call_qwen(messages)
        await session.close()
        return final.get("content", str(final))

```