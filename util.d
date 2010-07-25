/* Utility functions, mixins, constants and public imports of generally useful
 * Phobos modules.  These are not meant to be part of the public API,
 * at least for now.
 *
 * Copyright (C) 2010 David Simcha
 *
 * License:
 *
 * Boost Software License - Version 1.0 - August 17th, 2003
 *
 * Permission is hereby granted, free of charge, to any person or organization
 * obtaining a copy of the software and accompanying documentation covered by
 * this license (the "Software") to use, reproduce, display, distribute,
 * execute, and transmit the Software, and to prepare derivative works of the
 * Software, and to permit third-parties to whom the Software is furnished to
 * do so, all subject to the following:
 *
 * The copyright notices in the Software and this entire statement, including
 * the above license grant, this restriction and the following disclaimer,
 * must be included in all copies of the Software, in whole or in part, and
 * all derivative works of the Software, unless such copies or derivative
 * works are solely in the form of machine-executable object code generated by
 * a source language processor.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
 * SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
 * FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
module plot2kill.util;

public import std.conv, std.math, std.array, std.range, std.algorithm,
    std.contracts, std.traits, std.stdio, std.string, core.memory, std.path;

version(Windows) {
    // This should be available on all 32-bit versions of Windows.  It was
    // standard since Windows 3.1.
    immutable string defaultFont = "Arial";
} else version(Posix) {
    // This is an X11 core font, so it should be on pretty much any
    // non-embedded Posix system.
    immutable string defaultFont = "Helvetica";
} else {
    // Are non-ancient Macs Posix?  I hope so.
    static assert(0, "Don't know what a sane default font is for this platform.");
}

package double toSigFigs(double num, int nSigFigs)
in {
    assert(nSigFigs > 0);
} body {
    if(num == 0 || !isFinite(num)) {
        return num;
    }

    auto nZeros = to!int(log10(num)) - nSigFigs + 1;
    auto divisor = pow(10.0, nZeros);
    auto rounded = round(num / divisor);
    if(rounded == 0) {
        divisor /= 10;
        rounded = round(num / divisor);
    }

    return rounded * divisor;
}

unittest {
    assert(approxEqual(toSigFigs(0.001325356446, 1), 0.001));
    assert(approxEqual(toSigFigs(PI, 3), 3.14));
}

package enum toPixels = q{
    double toPixelsX(double inUnits) {
        immutable xRange = rightLim - leftLim;
        assert(xRange > 0);

        immutable fract = (inUnits - leftLim) / xRange;
        immutable ret = (fract * plotWidth) + leftMargin;
        return ret;
    }

    double toPixelsY(double inUnits) {
        immutable yRange = upperLim - lowerLim;
        assert(yRange > 0);

        immutable fract = (upperLim - inUnits) / yRange;
        immutable ret = (fract * plotHeight) + topMargin;
        return ret;
    }
};

package enum drawErrorMixin = q{
    void drawErrorBar(Pen pen, double x, double from, double to, double width) {
        immutable xPixels = toPixelsX(x);
        immutable fromPixels = toPixelsY(from);
        immutable toPixels = toPixelsY(to);
        immutable horizLeft = toPixelsX(x - width / 2);
        immutable horizRight = toPixelsX(x + width / 2);

        form.drawClippedLine(pen, PlotPoint(xPixels, fromPixels),
                             PlotPoint(xPixels, toPixels));
        form.drawClippedLine(pen, PlotPoint(horizLeft, toPixels),
                             PlotPoint(horizRight, toPixels));
    }
};

/* Converts an array of doubles to strings, rounding off numbers very close
 * to zero.
 */
package string[] doublesToStrings(double[] arr) {
    auto ret = new string[arr.length];
    foreach(i, elem; arr) {
        ret[i] = (abs(elem) > 1e-10) ? to!string(elem) : "0";
    }
    return ret;
}

double[] toDoubleArray(R)(R range) {
    double[] ret;
    static if(std.range.hasLength!R) {{
        ret.length = range.length;
        size_t i = 0;
        foreach(elem; range) {
            ret[i] = elem;
            i++;
        }
    }} else {
        foreach(elem; range) {
            ret ~= elem;
        }
    }

    return ret;
}

package bool nullOrInit(T)(T arg) {
    static if(is(T == class)) {
        return arg is null;
    } else {
        return arg == T.init;
    }
}

// For drawing columnar text if there's no support for real rotated text.
package string addNewLines(string input) {
    if(input.empty) {
        return null;
    }

    string ret;
    foreach(dchar elem; input) {
        ret ~= elem;
        ret ~= '\n';
    }

    return ret[0..$ - 1];
}


package struct PlotPoint {
    double x;
    double y;
}

package struct PlotRect {
    double x;
    double y;
    double width;
    double height;
}

void enforceSane(string file = __FILE__, int line = __LINE__)(PlotRect r) {
    if(!(r.x >= 0 && r.y >= 0 && r.width >= 0 && r.height >= 0)) {
        throw new Exception(text("Bad rectangle line ", line, " file ", file,
            ":  ", r));
    }
}

package struct PlotSize {
    double width;
    double height;
}

version(dfl) {
    private {
        static import core.stdc.stdlib;  // For malloc, free.

        // Used for writeBitmap.  This stuff was obtained from Wikipedia's
        // documentation of the BMP file format.
        immutable ubyte[2] magicNum = [0x42, 0x4D];
        immutable ubyte[4] wasteSpace = [0, 0, 0, 0];
        immutable ubyte[4] offset = [0x36, 0, 0, 0];
        immutable ubyte[4] headerBytesLeft = [0x28, 0, 0, 0];
        immutable ubyte[2] colorPlanes = [0x1, 0];
        immutable ubyte[2] bitsPerPixel = [0x18, 0];
        immutable ubyte[4] noCompression = [0, 0, 0, 0];
        immutable ubyte[4] hRes = [0, 0, 0, 0];
        immutable ubyte[4] vRes = hRes;
        immutable ubyte[4] paletteColors = [0, 0, 0, 0];
        immutable ubyte[4] importantColors = [0, 0, 0, 0];
        immutable ubyte[1] zeroUbyte = [0];
        enum headerSize = 54;

        // Since writing everything directly to a file is too slow, we write
        // to this buffer and then output this buffer to a file in one go.
        struct Buf {
            ubyte[] arr;
            size_t writeIndex;

            this(int size) {
                arr = (cast(ubyte*) core.stdc.stdlib.malloc(size))[0..size];
            }

            @disable this(this) {}

            ~this() {
                core.stdc.stdlib.free(cast(void*) arr.ptr);
            }

            void rawWrite(const ubyte[] writeThis) {
                assert(writeThis.length <= arr.length - writeIndex);
                arr[writeIndex..writeIndex + writeThis.length] = writeThis[];
                writeIndex += writeThis.length;
            }
        }
    }
}

// Write an arraay of pixels to a .bmp file.  Used to implement saving on DFL.
//
// BUGS:  Since for now this is only for saving on DFL, which is tied to
//        Windows, this function assumes it will be running on a little
//        endian platform.
//
//        Only supports 24-bit bitmaps.
void writeBitmap(Pixel)(Pixel[] pix, File handle, int width, int height) {
    enforce(height > 0);
    enforce(width > 0);
    enforce(pix.length == width * height);

    // TODO:  Make this support stuff other than little endian.
    static ubyte[] toUbyteArr(I)(ref I i) {
        return (cast(ubyte*) &i)[0..I.sizeof];
    }

    immutable rowSizeRaw = width * 3;
    int rowSizeAligned = rowSizeRaw;  // Rows have to be 4-byte aligned.
    int paddingBytes = 0;
    while(rowSizeAligned % 4 != 0) {
        rowSizeAligned++;
        paddingBytes++;
    }

    immutable int bitmapDataSize = rowSizeAligned * height;
    immutable int fileSize = bitmapDataSize + headerSize;

    auto buf = Buf(fileSize);

    buf.rawWrite(magicNum[]);
    buf.rawWrite(toUbyteArr(fileSize));
    buf.rawWrite(wasteSpace[]);
    buf.rawWrite(offset[]);
    buf.rawWrite(headerBytesLeft[]);
    buf.rawWrite(toUbyteArr(width));
    buf.rawWrite(toUbyteArr(height));
    buf.rawWrite(colorPlanes[]);
    buf.rawWrite(bitsPerPixel[]);
    buf.rawWrite(noCompression[]);
    buf.rawWrite(toUbyteArr(bitmapDataSize));
    buf.rawWrite(hRes[]);
    buf.rawWrite(vRes[]);
    buf.rawWrite(paletteColors[]);
    buf.rawWrite(importantColors[]);

    // Start of bitmap data.
    foreach(row; 0..height) {
        auto rowData = pix[width * row..width * (row + 1)];
        foreach(pixel; rowData) {
            buf.rawWrite(toUbyteArr(pixel.b));
            buf.rawWrite(toUbyteArr(pixel.g));
            buf.rawWrite(toUbyteArr(pixel.r));
        }

        foreach(i; 0..paddingBytes) {
            buf.rawWrite(zeroUbyte[]);
        }
    }

    handle.rawWrite(buf.arr);
    handle.flush();
}
