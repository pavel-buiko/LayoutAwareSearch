using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace LayoutAwareSearch.Search;

internal static class KeyboardLayoutConverter
{
    public static string[] GetQueries(string query)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return [];
        }

        query = query.Trim();
        var queries = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { query };
        // Read on every search so changes to the user's input languages take effect immediately.
        var layouts = GetLayouts();
        foreach (var source in layouts)
        {
            foreach (var target in layouts)
            {
                if (source != target)
                {
                    queries.Add(Convert(query, source, target));
                }
            }
        }

        return queries.ToArray();
    }

    internal static nint[] GetLayouts()
    {
        var layouts = new nint[GetKeyboardLayoutList(0, null)];
        var count = GetKeyboardLayoutList(layouts.Length, layouts);
        return layouts.Take(count).Distinct().ToArray();
    }

    internal static string Convert(string text, nint source, nint target)
    {
        var result = new StringBuilder(text.Length);
        var state = new byte[256];
        var buffer = new char[8];
        foreach (var character in text)
        {
            var key = VkKeyScanEx(character, source);
            if (key == -1 || char.IsWhiteSpace(character))
            {
                result.Append(character);
                continue;
            }

            // Use the physical key, not its virtual key: these differ on e.g. AZERTY/QWERTZ.
            var scanCode = MapVirtualKeyEx((uint)(key & 0xff), 4, source);
            var targetKey = MapVirtualKeyEx(scanCode, 3, target);
            if (scanCode == 0 || targetKey == 0)
            {
                result.Append(character);
                continue;
            }

            Array.Clear(state);
            state[0x10] = (byte)((key & 0x100) != 0 ? 0x80 : 0); // Shift
            state[0x11] = (byte)((key & 0x200) != 0 ? 0x80 : 0); // Ctrl
            state[0x12] = (byte)((key & 0x400) != 0 ? 0x80 : 0); // Alt / AltGr
            // Bit 2 prevents altering the keyboard's dead-key state. Never switch layouts.
            var count = ToUnicodeEx(targetKey, scanCode, state, buffer, buffer.Length, 4, target);
            if (count > 0 && count <= buffer.Length)
            {
                result.Append(buffer, 0, count);
            }
            else
            {
                // Dead keys / IME sequences cannot be reconstructed from a single character.
                result.Append(character);
            }
        }

        return result.ToString();
    }

    [DllImport("user32.dll")]
    private static extern int GetKeyboardLayoutList(int count, [Out] nint[]? layouts);

    [DllImport("user32.dll", EntryPoint = "VkKeyScanExW", CharSet = CharSet.Unicode)]
    private static extern short VkKeyScanEx(char character, nint layout);

    [DllImport("user32.dll", EntryPoint = "MapVirtualKeyExW")]
    private static extern uint MapVirtualKeyEx(uint code, uint mapType, nint layout);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int ToUnicodeEx(uint key, uint scanCode, byte[] state,
        [Out] char[] buffer, int bufferSize, uint flags, nint layout);
}
