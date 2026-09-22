"""Opt-in end-to-end check against an already loaded game; never launches the UI."""
import asyncio
import json
from pathlib import Path
import sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    root=Path(__file__).resolve().parents[1]
    params=StdioServerParameters(command=sys.executable,args=[str(root/'coach.py'),'serve'])
    async with stdio_client(params) as (reader,writer):
        async with ClientSession(reader,writer) as session:
            await session.initialize()
            assert len((await session.list_tools()).tools)==3
            city=None
            for tool,args in [('get_game_snapshot',{}),('get_visible_map',None),('get_recent_observations',{'limit':1}),('get_game_snapshot',{})]:
                if args is None:
                    assert city, 'Need a city to verify visible map'
                    args={'x':city['x'],'y':city['y'],'radius':3}
                response=await session.call_tool(tool,args)
                assert not response.isError,response
                data=response.structuredContent or json.loads(response.content[0].text)
                if tool=='get_recent_observations':
                    assert data['observations']
                else:
                    assert data['ok'],data
                    assert not [r for r in data['records'] if r.get('errors') or r['kind']=='error'],data
                    if tool=='get_game_snapshot':
                        city=next(r for r in data['records'] if r['kind']=='city')
                    print(next(r for r in data['records'] if r['kind']=='meta'))
                print(tool,'PASS')
            print('End-to-end checks passed.')

asyncio.run(main())
