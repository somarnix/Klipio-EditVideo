"""
Quick test of MCP server tools (without Klipio connection)
"""

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("Klipio Test")

@mcp.tool()
def test_tool(message: str) -> str:
    """A simple test tool."""
    return f"Received: {message}"

if __name__ == "__main__":
    print("🤖 Testing MCP Server...")
    print("If you see tool definitions, MCP is working!")
    print("\nPress Ctrl+C to stop\n")

    # This will show available tools
    mcp.run(transport="stdio")
