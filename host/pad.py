# /// script
# requires-python = ">=3.10"
# dependencies = ["pygame-ce>=2.5", "pyserial>=3.5"]
# ///
"""Play PacmanHDL on the board from your computer, over the USB-UART link.

    uv run host/pad.py              # finds the Tang Nano automatically
    uv run host/pad.py --port /dev/cu.usbserial-11101

Keep the small window focused. Keys (same as the simulator):
    Arrows / WASD  move          Z / Space  A  (wall-break key 1)
    Enter / P      Start/pause   X          B  (wall-break key 2)
                                 C          Select (wall-break key 3)
A game controller works too. The board gets one byte, the held-button mask
(rtl/io/gamepad.sv), on every change and at least every 100 ms; if it hears
nothing for 0.5 s it releases all buttons.
"""
import argparse
import sys

import pygame
import serial
from serial.tools import list_ports

UP, DOWN, LEFT, RIGHT, A, B, SELECT, START = (1 << i for i in range(8))
NAMES = ['Up', 'Down', 'Left', 'Right', 'A', 'B', 'Select', 'Start']

KEYS = {
    UP: (pygame.K_UP, pygame.K_w), DOWN: (pygame.K_DOWN, pygame.K_s),
    LEFT: (pygame.K_LEFT, pygame.K_a), RIGHT: (pygame.K_RIGHT, pygame.K_d),
    A: (pygame.K_z, pygame.K_SPACE), B: (pygame.K_x,), SELECT: (pygame.K_c,),
    START: (pygame.K_RETURN, pygame.K_p),
}
PAD_BUTTONS = {
    UP: pygame.CONTROLLER_BUTTON_DPAD_UP, DOWN: pygame.CONTROLLER_BUTTON_DPAD_DOWN,
    LEFT: pygame.CONTROLLER_BUTTON_DPAD_LEFT, RIGHT: pygame.CONTROLLER_BUTTON_DPAD_RIGHT,
    A: pygame.CONTROLLER_BUTTON_A, B: pygame.CONTROLLER_BUTTON_B,
    SELECT: pygame.CONTROLLER_BUTTON_BACK, START: pygame.CONTROLLER_BUTTON_START,
}
HEARTBEAT_MS = 100


def find_port():
    """The Tang Nano's BL702 shows up as an FT2232 (0403:6010): interface 0 is
    JTAG, interface 1 is the UART. On macOS that is the /dev/cu.usbserial-*1."""
    ports = sorted((p for p in list_ports.comports() if (p.vid, p.pid) == (0x0403, 0x6010)),
                   key=lambda p: p.device)
    return ports[-1] if ports else None


def keyboard_mask(keys):
    return sum(bit for bit, codes in KEYS.items() if any(keys[k] for k in codes))


def controller_mask(pads):
    mask = 0
    for pad in pads:
        mask |= sum(bit for bit, b in PAD_BUTTONS.items() if pad.get_button(b))
        x, y = pad.get_axis(pygame.CONTROLLER_AXIS_LEFTX), pad.get_axis(pygame.CONTROLLER_AXIS_LEFTY)
        mask |= (UP if y < -16000 else 0) | (DOWN if y > 16000 else 0)
        mask |= (LEFT if x < -16000 else 0) | (RIGHT if x > 16000 else 0)
    return mask


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--port', help='serial device (default: auto-detect the Tang Nano)')
    ap.add_argument('--baud', type=int, default=115200)
    args = ap.parse_args()

    port = args.port or getattr(find_port(), 'device', None)
    if not port:
        sys.exit('No Tang Nano found; pass --port (see `ls /dev/cu.usbserial-*`).')
    link = serial.Serial(port, args.baud, timeout=0)

    pygame.init()
    pygame.display.set_caption(f'PacmanHDL pad - {port}')
    screen = pygame.display.set_mode((420, 120))
    font = pygame.font.SysFont(None, 26)
    clock = pygame.time.Clock()
    pads = []

    sent, last_send = None, 0
    running = True
    while running:
        for e in pygame.event.get():
            if e.type == pygame.QUIT or (e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE):
                running = False
            elif e.type == pygame.CONTROLLERDEVICEADDED:
                pads.append(pygame.controller.Controller(e.device_index))

        mask = keyboard_mask(pygame.key.get_pressed()) | controller_mask(pads)
        now = pygame.time.get_ticks()
        if mask != sent or now - last_send >= HEARTBEAT_MS:
            link.write(bytes([mask]))
            sent, last_send = mask, now

        screen.fill((0, 0, 0))
        held = ' '.join(n for i, n in enumerate(NAMES) if mask >> i & 1) or '-'
        screen.blit(font.render(f'held: {held}', True, (255, 220, 0)), (12, 20))
        screen.blit(font.render(f'{port}  {args.baud} baud   Esc quits', True, (140, 140, 140)), (12, 70))
        pygame.display.flip()
        clock.tick(250)

    link.write(b'\x00')
    link.close()


if __name__ == '__main__':
    main()
