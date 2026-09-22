import asyncio
import re
import struct
import unittest
import sys
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import coach


class ProtocolTests(unittest.IsolatedAsyncioTestCase):
    async def exercise(self, truncated=False):
        async def game(reader, writer):
            try:
                self.assertEqual((await coach.receive(reader))[1], 'APP:')
                self.assertEqual((await coach.receive(reader))[1], 'LSQ:')
                await coach.send(writer,4,'Civilization VI')
                await coach.send(writer,4,'LSR:\x007\x00GameCore_Tuner\x0011\x00InGame')
                _,cmd=await coach.receive(reader)
                self.assertTrue(cmd.startswith('CMD:11:'))
                begin=re.search(r'COACH_BEGIN_[a-f0-9]+',cmd)[0]
                end=re.search(r'COACH_END_[a-f0-9]+',cmd)[0]
                await coach.send(writer,3,'O\x00InGame: unrelated old output')
                await coach.send(writer,3,'O\x00InGame: '+begin)
                await coach.send(writer,3,'O\x00InGame: {"turn":2}')
                if not truncated:
                    await coach.send(writer,3,'O\x00InGame: '+end)
            finally:
                writer.close()
                await writer.wait_closed()
        server=await asyncio.start_server(game,'127.0.0.1',0)
        async with server:
            return await coach.query('print("test")',port=server.sockets[0].getsockname()[1])

    async def test_handshake_and_stale_output(self):
        self.assertEqual(await self.exercise(),['{"turn":2}'])

    async def test_partial_response_is_not_success(self):
        with self.assertRaises(coach.NotReady):
            await self.exercise(truncated=True)

    async def test_oversize_frame(self):
        reader=asyncio.StreamReader()
        reader.feed_data(struct.pack('<Ii',9_000_000,3))
        with self.assertRaises(coach.NotReady):
            await coach.receive(reader)

    async def test_map_rejects_code_injection(self):
        with self.assertRaises(ValueError):
            await coach.capture('map','0); Game.DoTurn()',0,3)

    async def test_mcp_surface_read_only(self):
        tools=await coach.create_server().list_tools()
        self.assertEqual({t.name for t in tools},{'get_game_snapshot','get_visible_map','get_recent_observations'})
        self.assertTrue(all(t.annotations.readOnlyHint for t in tools))


if __name__=='__main__':
    unittest.main()
