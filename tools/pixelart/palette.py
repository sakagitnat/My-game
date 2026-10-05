"""The shared palette of the Salvora pixel art (taken from the owner's seaside reference: warm wood, cream, blue, brass).
Every piece uses only these colours, so pieces drawn at different times still match."""
def h(s): return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
P = {
    'out': h('#3b2416'),                       # darkest brown, outlines
    'w0': h('#6e4023'), 'w1': h('#8c5836'), 'w2': h('#a46840'), 'w3': h('#ba774a'), 'w4': h('#c67f4d'), 'w5': h('#d68f58'), 'w6': h('#e8a56f'),   # wood, dark to light
    'c0': h('#b49f8c'), 'c1': h('#d1c1b3'), 'c2': h('#e8d6c7'), 'c3': h('#f2e4d6'), 'c4': h('#fbefda'),                                           # cream, dark to light
    'b0': h('#2f5170'), 'b1': h('#366c9c'), 'b2': h('#2c79b7'), 'b3': h('#3885c0'), 'b4': h('#5fa6d6'),                                           # blue, dark to light
    'g0': h('#7fb4d2'), 'g1': h('#a3d0e6'), 'g2': h('#cde8f2'),                                                                                  # glass
    's0': h('#333942'), 's1': h('#4d5560'), 's2': h('#6c7580'), 's3': h('#8aa7b9'),                                                              # charcoal / steel
    'r0': h('#b8862e'), 'r1': h('#e0b062'), 'r2': h('#f3d089'),                                                                                  # brass
    'p0': h('#c9573f'), 'p1': h('#e0715a'), 'y0': h('#f0c24a'), 'l0': h('#3f7a43'), 'l1': h('#5fa05a'), 'l2': h('#8cc56a'),                         # flowers and leaves
}
T = (0, 0, 0, 0)
