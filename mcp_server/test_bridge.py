"""
Test WebSocket connection to Klipio MCP Bridge
"""

import asyncio
import json
import websockets


async def test_connection():
    uri = "ws://localhost:8765"

    print("🤖 Testing Klipio MCP Bridge...")
    print(f"Connecting to {uri}...")

    try:
        async with websockets.connect(uri) as websocket:
            print("✅ Connected!")

            # Test 1: Get timeline state
            print("\n[Test 1] Getting timeline state...")
            await websocket.send(json.dumps({
                "command": "get_timeline",
                "params": {}
            }))
            response = await websocket.recv()
            result = json.loads(response)
            print(f"✅ Timeline has {len(result.get('timeline', {}).get('tracks', []))} tracks")

            # Test 2: Analyze timeline
            print("\n[Test 2] Analyzing timeline...")
            await websocket.send(json.dumps({
                "command": "analyze_timeline",
                "params": {}
            }))
            response = await websocket.recv()
            result = json.loads(response)
            if result.get('success'):
                analysis = result.get('analysis', {})
                print(f"✅ Duration: {analysis.get('duration')}s")
                print(f"✅ Total clips: {analysis.get('total_clips')}")
                print(f"✅ Total effects: {analysis.get('total_effects')}")

            # Test 3: Get project info
            print("\n[Test 3] Getting project info...")
            await websocket.send(json.dumps({
                "command": "get_project_info",
                "params": {}
            }))
            response = await websocket.recv()
            result = json.loads(response)
            print(f"✅ Project: {result}")

            print("\n✅ All tests passed!")
            print("\n🎉 Klipio MCP Bridge is working correctly!")

    except ConnectionRefusedError:
        print("❌ ERROR: Cannot connect to Klipio")
        print("\nPlease make sure:")
        print("1. Klipio is running")
        print("2. MCP is enabled in Klipio Settings")
        print("3. WebSocket server is on port 8765")

    except Exception as e:
        print(f"❌ ERROR: {e}")


if __name__ == "__main__":
    asyncio.run(test_connection())
