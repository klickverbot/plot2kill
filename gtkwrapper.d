/**This file contains the GTK-specific parts of Plot2Kill and is publicly
 * imported by plot2kill.figure if compiled with -version=gtk.  This is even
 * more a work in progress than the DFL version.
 *
 * BUGS:
 *
 * 1.  Text word wrap doesn't work yet because the gtkD text drawing API is
 *     missing some functionality.
 *
 * 2.  HeatMap is beyond slow.
 *
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
module plot2kill.gtkwrapper;

version(gtk) {

import plot2kill.util;

import gdk.Color, gdk.GC, gtk.Widget, gdk.Drawable, gtk.DrawingArea,
    gtk.MainWindow, gtk.Main, gdk.Window, gtk.Container, gtk.Window,
    gdk.Pixbuf, gdk.Pixmap, gtkc.all, gtk.FileChooserDialog, gtk.Dialog,
    gtk.FileFilter, gobject.ObjectG, cairo.Context, cairo.FontFace,
    gtkc.cairotypes;

/**GTK's implementation of a color object.*/
struct Color {
    ubyte r;
    ubyte g;
    ubyte b;
}

/**Holds context for drawing lines.*/
struct Pen {
    Color color;
    double lineWidth;
}

/**Holds context for drawing rectangles.*/
struct Brush {
    Color color;
}

///
struct Point {
    ///
    int x;

    ///
    int y;
}

///
struct Rect {
    ///
    int x;

    ///
    int y;

    ///
    int width;

    ///
    int height;
}

///
struct Size {
    ///
    int width;

    ///
    int height;
}

/**Holds font information.*/
alias cairo.FontFace.FontFace font;

/**Get a color in a GUI framework-agnostic way.*/
Color getColor(ubyte red, ubyte green, ubyte blue) {
    return Color(red, green, blue);
}

/**Get a font in a GUI framework-agnostic way.*/
struct Font {
    FontFace face;
    double size;
}

Font getFont(string fontName, double size) {
    return Font(
        Context.toyFontFaceCreate(
            fontName,
            cairo_font_slant_t.NORMAL,
            cairo_font_weight_t.NORMAL
        ), size
    );
}


///
enum TextAlignment {
    ///
    Left = 0,

    ///
    Center = 1,

    ///
    Right = 2
}

// This calls the relevant lib's method of cleaning up the given object, if
// any.
void doneWith(T)(T garbage) {
    static if(is(T : gdk.GC.GC) || is(T : gdk.Pixmap.Pixmap) ||
              is(T : gdk.Pixbuf.Pixbuf)) {
        // Most things seem to manage themselves fine, but these objects
        // leak like a seive.
        garbage.unref();

        // Since we're already in here be dragons territory, we may as well:
        core.memory.GC.free(cast(void*) garbage);
    }
}

alias Rect PlotRect;

/**The base class for both FigureBase and Subplot.  Holds common functionality
 * like saving and text drawing.
 */
abstract class PlotDrawingBase : DrawingArea {
    mixin(GuiAgnosticBaseMixin);

private:
    enum ubyteMax = cast(double) ubyte.max;

protected:
    Context context;

public:
    // All this stuff that's public but not documented would be package at least
    // for now if package worked.  If you're a user of this lib and not a
    // developer of it, please be advised that this stuff is in no way stable
    // and could change at any time.  Some of it will eventually be exposed,
    // but I'm not sure how yet.

    final void drawLine(Pen pen, int startX, int startY, int endX, int endY) {
        context.save();
        scope(exit) context.restore();

        auto c = pen.color;
        context.setSourceRgb(c.r / ubyteMax, c.g / ubyteMax, c.b / ubyteMax);
        context.setLineWidth(pen.lineWidth);
        context.moveTo(startX + xOffset, startY + yOffset);
        context.lineTo(endX + xOffset, endY + yOffset);
        context.stroke();
    }

    final void drawLine(Pen pen, Point start, Point end) {
        this.drawLine(pen, start.x, start.y, end.x, end.y);
    }

    final void drawRectangle(Pen pen, int x, int y, int width, int height) {
        context.save();
        scope(exit) context.restore();

        auto c = pen.color;
        context.setSourceRgb(c.r / ubyteMax, c.g / ubyteMax, c.b / ubyteMax);
        context.setLineWidth(pen.lineWidth);
        context.rectangle(x + xOffset, y + yOffset, width, height);
        context.stroke();
    }

    final void drawRectangle(Pen pen, Rect r) {
        this.drawRectangle(pen, r.x, r.y, width, height);
    }

    final void fillRectangle(Brush brush, int x, int y, int width, int height) {
        context.save();
        scope(exit) context.restore();

        auto c = brush.color;
        enum ubyteMax = cast(double) ubyte.max;
        context.setSourceRgb(c.r / ubyteMax, c.g / ubyteMax, c.b / ubyteMax);
        context.rectangle(x + xOffset, y + yOffset, width, height);
        context.fill();
    }

    final void fillRectangle(Brush brush, Rect r) {
        this.fillRectangle(brush, r.x, r.y, r.width, r.height);
    }

    final void drawText(
        string text,
        Font font,
        Color pointColor,
        PlotRect rect,
        TextAlignment alignment
    ) {
        context.save();
        scope(exit) context.restore();

        drawTextCurrentContext(text, font, pointColor, rect, alignment);
    }

    final void drawTextCurrentContext(
        string text,
        Font font,
        Color pointColor,
        PlotRect rect,
        TextAlignment alignment
    ) {
        alias rect r;  // save typing
        Size measurements = measureText(text, font);
        if(measurements.width > rect.width) {
            alignment = TextAlignment.Left;
        }

        if(alignment == TextAlignment.Left) {
            r = PlotRect(
                r.x,
                r.y + measurements.height,
                r.width,
                r.height
            );
        } else if(alignment == TextAlignment.Center) {
            r = PlotRect(
                r.x + (r.width - measurements.width) / 2,
                r.y + measurements.height,
                r.width, r.height
            );
        } else if(alignment == TextAlignment.Right) {
            r = PlotRect(
                r.x + (r.width - measurements.width),
                r.y + measurements.height,
                r.width, r.height
            );
        } else {
            assert(0);
        }

        //context.rectangle(r.x, r.y - measurements.height, r.width, r.height);
        //context.clip();
        context.setFontSize(font.size);
        context.setFontFace(font.face);

        alias pointColor c;
        context.setSourceRgb(c.r / ubyteMax, c.g / ubyteMax, c.b / ubyteMax);

        context.setLineWidth(0.5);
        context.moveTo(r.x + xOffset, r.y + yOffset);
        context.textPath(text);
        context.fill();
    }

    final void drawText(
        string text,
        Font font,
        Color pointColor,
        PlotRect rect
    ) {
        drawText(text, font, pointColor, rect, TextAlignment.Left);
    }

    final void drawRotatedText(
        string text,
        Font font,
        Color pointColor,
        PlotRect rect,
        TextAlignment alignment
    ) {
        context.save();
        scope(exit) context.restore;
        context.newPath();

        alias rect r;  // save typing
        Size measurements = measureText(text, font);
        immutable slack  = rect.height - measurements.width;
        if(slack < 0) {
            alignment = TextAlignment.Left;
        }

        if(alignment == TextAlignment.Left) {
            r = PlotRect(
                r.x + r.width,
                r.y + r.height,
                r.width,
                r.height
            );
        } else if(alignment == TextAlignment.Center) {
            r = PlotRect(
                r.x + r.width,
                r.y + r.height - slack / 2,
                r.width, r.height
            );
        } else if(alignment == TextAlignment.Right) {
            r = PlotRect(
                r.x + r.width,
                r.y + r.height - slack,
                r.width, r.height
            );
        } else {
            assert(0);
        }
        //context.rectangle(r.x, r.y - measurements.height, r.width, r.height);
        //context.clip();
        context.setFontSize(font.size);
        context.setFontFace(font.face);

        alias pointColor c;
        context.setSourceRgb(c.r / ubyteMax, c.g / ubyteMax, c.b / ubyteMax);

        context.setLineWidth(0.5);
        context.moveTo(r.x + xOffset, r.y + yOffset);
        context.rotate(PI * 1.5);
        context.textPath(text);
        context.fill();
    }

    final void drawRotatedText(
        string text,
        Font font,
        Color pointColor,
        Rect rect
    ) {
        drawRotatedText(text, font, pointColor, rect, TextAlignment.Left);
    }

    // BUGS:  Ignores maxWidth.
    final Size measureText
    (string text, Font font, int maxWidth, TextAlignment alignment) {
        return measureText(text, font);
    }

    // BUGS:  Ignores maxWidth.
    final Size measureText(string text, Font font, int maxWidth) {
        return measureText(text, font);

    }

    final Size measureText(string text, Font font) {
        context.save();
        scope(exit) context.restore();

        context.setLineWidth(1);
        context.setFontSize(font.size);
        context.setFontFace(font.face);
        cairo_text_extents_t ext;

        context.textExtents(text, &ext);
        return Size(roundTo!int(ext.width), roundTo!int(ext.height));
    }

    // TODO:  Add support for stuff other than solid brushes.
    /*Get a brush in a GUI framework-agnostic way.*/
    static Brush getBrush(Color color) {
        return Brush(color);
    }

    /*Get a pen in a GUI framework-agnostic way.*/
    static Pen getPen(Color color, int width = 1) {
        return Pen(color, width);
    }

    final int width()  {
       if(_width > 0) {
           return _width;
       }

       GtkRequisition req;
       this.sizeRequest(req);
       return req.width;
    }

    final int height()  {
       if(_height > 0) {
           return _height;
       }

       GtkRequisition req;
       this.sizeRequest(req);
       return req.height;
    }

    void parentSizeChanged(GtkAllocation* alloc, Widget widget) {
        if(this.width != alloc.width || this.height != alloc.height) {
            this.setSizeRequest(alloc.width, alloc.height);
        }
    }

    private bool realized;
    final void draw() {
        bool ownContext;
        if(this.context is null) {
            ownContext = true;
            enforce(getParent() !is null, this.classinfo.name);

            if(!realized) {
                this.realize();
                realized = true;
            }
            this.context = new Context(getWindow());
        }

        drawImpl();
        if(ownContext) {
            context.destroy();
        }
        this.context = null;
    }

    abstract void drawImpl() {}

    void drawTo(Context context) {
        drawTo(context, this.width, this.height);
    }

    // Weird function overloading bugs.  This should be removed.
    void drawTo(Context context, int width, int height) {
        return drawTo(context, Rect(0, 0, width, height));
    }

    // Allows drawing at an offset from the origin.
    void drawTo(Context context, Rect whereToDraw) {
        // Save the default class-level values, make the values passed in the
        // class-level values, call drawImpl(), then restore the default values.
        auto oldContext = this.context;
        auto oldWidth = this._width;
        auto oldHeight = this._height;
        auto oldXoffset = this.xOffset;
        auto oldYoffset = this.yOffset;

        scope(exit) {
            this.context = oldContext;
            this._height = oldHeight;
            this._width = oldWidth;
            this.xOffset = oldXoffset;
            this.yOffset = oldYoffset;
        }

        this.context = context;
        this._width = whereToDraw.width;
        this._height = whereToDraw.height;
        this.xOffset = whereToDraw.x;
        this.yOffset = whereToDraw.y;
        draw();
    }

    /**Saves this figure to a file.  The file type can be either .png,
     * .jpg, .ico, .tiff, or .bmp.  width and height allow you to specify
     * explicit width and height parameters for the image file.  These will
     * not affect the width and height properties of this object after this
     * method returns.  If width and height are left at their default values
     * of 0, the current object-level width and height properties will be
     * used.
     */
    void saveToFile
    (string filename, string type, int width = 0, int height = 0) {
        // TODO:  Use Cairo to save this stuff.
        if(width <= 0 || height <= 0) {
            width = this.width;
            height = this.height;
        }

        auto pixmap = new Pixmap(null, width, height, 24);
        scope(exit) doneWith(pixmap);

        auto c = new Context(pixmap);
        scope(exit) c.destroy();

        drawTo(c, width, height);
        auto pixbuf = new Pixbuf(pixmap, 0, 0, width, height);
        scope(exit) doneWith(pixbuf);

        pixbuf.savev(filename, type, null, null);
    }

    /**Draw and display the figure as a main form.  This is useful in
     * otherwise console-based apps that want to display a few plots.
     * However, you can't have another main form up at the same time.
     */
    void showAsMain() {
        auto mw = new DefaultPlotWindow!(MainWindow)(this);
        Main.run();
    }

    /**Returns a default plot window with this figure in it.*/
    gtk.Window.Window getDefaultWindow() {
        return new DefaultPlotWindow!(gtk.Window.Window)(this);
    }
}



/**The GTK-specific parts of the Figure class.  These include wrappers around
 * the subset of drawing functionality used by Plot2Kill.
 *
 * In the GTK version of this lib, the Figure class can be used in two ways.
 * It can be used as a Widget and in this case will implicitly draw on itself,
 * or it can draw its plots to an arbitrary Drawable.  For now, a limitation
 * of this is that the arbitrary drawable must have the same depth as this
 * object's default Drawable, which is 24 bits.
 */
class FigureBase : PlotDrawingBase {
private:
    // Fudge factors for the space that window borders take up.  TODO:
    // Figure out how to get the actual numbers and use them instead of these
    // stupid fudge factors.
    enum verticalBorderSize = 0;
    enum horizontalBorderSize = 0;

    bool onDrawingExpose(GdkEventExpose* event, Widget drawingArea) {
        draw();
        return true;
    }

protected:
    this() {
        super();
        this.addOnExpose(&onDrawingExpose);
        this.setSizeRequest(800, 600);  // Default size.
    }


public:
// Begin "real" public API.

    /**Draw the plot to the internal drawable.*/
    abstract void drawImpl() {}

    final void doneDrawing() {}
}

/**Default plot window.  It's a subclass of either Window or MainWindow
 * depending on the template parameter.
 */
template DefaultPlotWindow(Base)
if(is(Base == gtk.Window.Window) || is(Base == gtk.MainWindow.MainWindow)) {

    ///
    class DefaultPlotWindow : Base {
    private:
        PlotDrawingBase fig;

        immutable string[4] saveTypes =
            ["*.png", "*.bmp", "*.tiff", "*.jpeg"];

        // Based on using print statements to figure it out.  If anyone can
        // find the right documentation and wants to convert this to a proper
        // enum, feel free.
        enum rightClick = 3;


        void saveDialogResponse(int response, Dialog d) {
            auto fc = cast(FileChooserDialog) d;
            assert(fc);

            if(response == GtkResponseType.GTK_RESPONSE_OK) {
                string name = fc.getFilename();
                auto fileType = fc.getFilter().getName();

                fig.saveToFile(name, fileType);
                d.destroy();
            } else {
                d.destroy();
            }
        }


        bool clickEvent(GdkEventButton* event, Widget widget) {
            if(event.button != rightClick) {
                return false;
            }


            auto fc = new FileChooserDialog("Save plot...", this,
               GtkFileChooserAction.SAVE);
            fc.setDoOverwriteConfirmation(1);  // Why isn't this the default?
            fc.addOnResponse(&saveDialogResponse);

            foreach(ext; saveTypes) {
                auto filter = new FileFilter();
                filter.setName(ext[2..$]);
                filter.addPattern(ext);
                fc.addFilter(filter);
            }

            fc.run();
            return true;
        }

    public:
        ///
        this(PlotDrawingBase fig) {
            super("Plot Window.  Right-click to save plot.");
            this.fig = fig;
            this.add(fig);
            this.resize(fig.width, fig.height);
            this.setUsize(400, 300);

            this.addOnButtonPress(&clickEvent);
            fig.addOnSizeAllocate(&fig.parentSizeChanged);
            fig.showAll();
            fig.queueDraw();
            this.showAll();
        }
    }
}

}
