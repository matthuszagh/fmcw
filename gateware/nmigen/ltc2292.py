from nmigen import Module, Elaboratable, Signal


class LTC2292(Elaboratable):
    """
    """

    def __init__(self, posedge_domain, negedge_domain):
        """
        """
        self._width = 12
        self._posedge_domain = posedge_domain
        self._negedge_domain = negedge_domain
        self.di = Signal(self._width)
        self.dao = Signal(self._width)
        self.dbo = Signal(self._width)

    def elaborate(self, platform):
        """
        """
        m = Module()

        dbuf = Signal(self._width)

        m.d[self._posedge_domain] += [self.dao.eq(dbuf), self.dbo.eq(self.di)]
        m.d[self._negedge_domain] += dbuf.eq(self.di)

        return m
