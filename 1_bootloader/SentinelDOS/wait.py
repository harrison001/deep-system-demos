import gdb

class WaitForCondition(gdb.Command):
    def __init__(self):
        super(WaitForCondition, self).__init__("wait_until_match", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        while True:
            gdb.execute("stepi", to_string=True)
            ax = int(gdb.parse_and_eval("$ax"))
            es = int(gdb.parse_and_eval("$es"))
            bx = int(gdb.parse_and_eval("$bx"))
            ah = (ax >> 8) & 0xff
            al = ax & 0xff
            ch = int(gdb.parse_and_eval("$ch"))
            cl = int(gdb.parse_and_eval("$cl"))
            dh = int(gdb.parse_and_eval("$dh"))

            if (ax == 0x2000 and es == 0x2000 and bx == 0 and ah == 0x02 and
                al == 2 and ch == 0 and cl == 2 and dh == 0):
                eip = int(gdb.parse_and_eval("$eip"))
                print(f"✅ 条件满足，当前 EIP: 0x{eip:x}")
                break

WaitForCondition()