/**This file contains Figure, which is a holds and draws one or more Plots 
 * onto a drawable surface.
 *
 * Copyright (C) 2010-2011 David Simcha
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
module plot2kill.figure;

import plot2kill.plot, plot2kill.util, std.typetuple, std.random;

version(dfl) {
    public import plot2kill.dflwrapper;
} else version(gtk) {
    public import plot2kill.gtkwrapper;
}

package enum legendSymbolSize = 15;  // 30 by 30 pixels.
package enum legendSymbolTextSpace = 3;

/**A container form for one or more Plot objects.
 *
 * Examples:
 * ---
 * auto nums = [1,1,1,1,2,2,3,3,4,5,6,7];
 * auto hist = Histogram(nums, 10);
 * auto fig = new Figure;
 * fig.addPllot(hist);
 * fig.title = "A plot";
 * fig.xLabel = "X label";
 * fig.yLabel = "Y label";
 * fig.showAsMain();
 * ---
 */
class Figure : FigureBase {
private:
    double upperLim = -double.infinity;
    double lowerLim = double.infinity;
    double leftLim = double.infinity;
    double rightLim = -double.infinity;

    // These control whether to auto set the axes.
    bool userSetXAxis = false;
    bool userSetYAxis = false;

    bool _horizontalGrid;
    bool _verticalGrid;

    bool _rotatedXTick;
    bool _rotatedYTick;

    enum tickPixels = 10;
    enum legendMarginHoriz = 20;
    enum legendMarginVert = 10;
    double xTickLabelWidth;
    double yTickLabelWidth;
    double tickLabelHeight;

    Pen axesPen;
    ubyte _gridIntensity = 128;
    Pen gridPen;

    Font _axesFont;
    Font _legendFont;

    Color[] _xTickColors;
    Color[] _yTickColors;

    LegendLocation _legendLoc = LegendLocation.bottom;

    void fixTickSizes() {
        void fixTickLabelSize(ref double toFix, string[] axisText) {
            toFix = 0;
            foreach(lbl; axisText) {
                auto lblSize = measureText(lbl, _axesFont);
                if(lblSize.height > tickLabelHeight) {
                    tickLabelHeight = lblSize.height;
                }

                if(lblSize.width > toFix) {
                    toFix = lblSize.width;
                }
            }
        }

        tickLabelHeight = 0;
        fixTickLabelSize(xTickLabelWidth, xAxisText);
        fixTickLabelSize(yTickLabelWidth, yAxisText);
    }

    void fixMargins() {
        fixTickSizes();
        immutable legendMeasure = measureLegend();
        immutable legendHeight = legendMeasure.height;
        immutable legendWidth = legendMeasure.width;

        immutable xLabelSize = measureText(xLabel(), xLabelFont());
        immutable bottomTickHeight = (rotatedXTick()) ?
            xTickLabelWidth : tickLabelHeight;
        immutable leftTickWidth = (rotatedYTick()) ?
            tickLabelHeight : yTickLabelWidth;

        bottomMargin = bottomTickHeight + tickPixels + xLabelSize.height
            + (legendLocation() == LegendLocation.bottom) * legendHeight + 20;

        topMargin = measureText(title(), titleFont(), plotWidth).height
            + (legendLocation() == LegendLocation.top) * legendHeight + 20;

        leftMargin = measureText(yLabel(), yLabelFont()).height +
             tickPixels + leftTickWidth
             + (legendLocation() == LegendLocation.left) * legendWidth + 30;

        rightMargin = (legendLocation() == LegendLocation.right)
            * legendWidth + 30;
    }

    Tuple!(double, "height", double, "width", int, "nRows") measureLegend() {
        immutable alwaysWrap = legendLocation() == LegendLocation.right ||
            legendLocation() == LegendLocation.left;

        PlotSize ret = PlotSize(0, 0);

        double maxHeight = 0;
        double maxWidth = 0;
        int nRows = 1;
        double rowPos = legendMarginHoriz;

        bool shouldReturnZero = true;
        foreach(plot; plotData) {
            if(plot.hasLegend && plot.legendText().length) {
                shouldReturnZero = false;
            }
        }

        if(shouldReturnZero) {
            return typeof(return)(0, 0, 0);
        }

        foreach(plot; plotData) if(plot.hasLegend) {
            auto itemSize = plot.measureLegend(legendFont(), this);
            maxHeight = max(maxHeight, itemSize.height);
            maxWidth = max(maxWidth, itemSize.width);

            if(alwaysWrap ||
            (itemSize.width + rowPos >= this.width - legendMarginHoriz
            && rowPos > legendMarginHoriz)) {
                nRows++;
                rowPos = itemSize.width + legendMarginHoriz;
            }

            rowPos += itemSize.width + legendMarginHoriz;
        }

        return typeof(return)(
            (maxHeight + legendMarginVert) * nRows,
            maxWidth + legendMarginHoriz,
            nRows
        );
    }

    FigureLine[] extraLines;

    final double plotWidth()  {
        return this.width - leftMargin - rightMargin;
    }

    final double plotHeight()  {
        return this.height - topMargin - bottomMargin;
    }

    mixin(toPixels);

    void drawTitle() {
        if(nullOrInit(titleFont())) {
            return;
        }

        auto height = measureText(title(), titleFont()).height;
        auto rect = PlotRect(leftMargin,
            10, this.plotWidth, height);
        auto format = TextAlignment.Center;
        drawText(title(), titleFont(), getColor(0, 0, 0), rect, format);
    }

    void drawXlabel() {
        if(nullOrInit(xLabelFont())) {
            return;
        }

        immutable textSize = measureText(xLabel(), xLabelFont());
        immutable yTop = this.height - textSize.height - 10
            - (legendLocation() == LegendLocation.bottom) *
                measureLegend().height;
        auto rect = PlotRect(leftMargin, yTop,
            this.width - leftMargin - rightMargin, textSize.height);

        auto format = TextAlignment.Center;
        drawText(xLabel(), xLabelFont(), getColor(0, 0, 0), rect, format);
    }

    void drawYlabel() {
        if(nullOrInit(yLabelFont()) || yLabel().length == 0) {
            return;
        }

        immutable textSize = measureText(yLabel(), yLabelFont());
        immutable margin = (plotHeight - textSize.width) / 2 + topMargin;
        immutable xCoord = 10 + measureLegend().width
            * (legendLocation() == LegendLocation.left);

        auto rect = PlotRect(xCoord, margin, textSize.height, textSize.width);

        drawRotatedText(yLabel(),
            yLabelFont(), getColor(0, 0, 0), rect, TextAlignment.Center);
    }

    void drawExtraLines() {
        foreach(line; extraLines) {
            auto pen = getPen(line.lineColor, line.lineWidth);
            scope(exit) doneWith(pen);

            auto start = PlotPoint(toPixelsX(line.x1), toPixelsY(line.y1));
            auto end = PlotPoint(toPixelsX(line.x2), toPixelsY(line.y2));
            drawClippedLine(pen, start, end);
        }
    }

    void drawAxes() {
        immutable origin = PlotPoint(toPixelsX(leftLim), toPixelsY(lowerLim));
        immutable topLeft = PlotPoint(origin.x, toPixelsY(upperLim));
        immutable bottomRight = PlotPoint(toPixelsX(rightLim), origin.y);

        drawLine(axesPen, origin, topLeft);
        drawLine(axesPen, origin, bottomRight);
    }

    void drawTicks() {
        auto black = getColor(0, 0, 0);

        foreach(i, tickPoint; xAxisLocations) {
            auto color = (_xTickColors.length) ? _xTickColors[i] : black;
            drawXTick(tickPoint, xAxisText[i], color);
        }

        foreach(i, tickPoint; yAxisLocations) {
            auto color = (_yTickColors.length) ? _yTickColors[i] : black;
            drawYTick(tickPoint, yAxisText[i], color);
        }
    }

    void drawLegend() {
        immutable loc = legendLocation();
        if(loc == LegendLocation.top || loc == LegendLocation.bottom) {
            drawLegendImplTopBottom();
        } else {
            drawLegendImplLeftRight();
        }
    }

    void drawLegendImplTopBottom() {
        immutable measurements = measureLegend();
        if(measurements.height == 0) return;  // No legend.
        immutable rowHeight = measurements.height / measurements.nRows;

        // This needs to be precomputed for centering purposes.
        double[] rowStarts;

        double curX = legendMarginHoriz;

        immutable loc = legendLocation();
        double curY;
        if(loc == LegendLocation.bottom) {
            curY = this.height - measurements.height - 10;
        } else {
            assert(loc == LegendLocation.top);
            curY = measureText(title(), titleFont()).height + 10;
        }

        size_t rowStartIndex = 0;

        foreach(plot; plotData) {
            if(!plot.legendText.length) continue;
            immutable itemSize = plot.measureLegend(legendFont(), this);

            if(itemSize.width + curX >= this.width - legendMarginHoriz
            && curX > legendMarginHoriz) {
                // Find centering.
                auto rowSize = curX - legendMarginHoriz;
                rowStarts ~= max(0, (this.width - rowSize) / 2);
                curX = legendMarginHoriz;
            }

            curX += itemSize.width + legendMarginHoriz;
        }
        // Append last row.
        auto rowSize = curX - legendMarginHoriz;
        rowStarts ~= max(0, (this.width - rowSize) / 2);

        curX = rowStarts[rowStartIndex];
        double nextX;

        foreach(plot; plotData) {
            if(!plot.legendText.length) continue;

            immutable itemSize = plot.measureLegend(legendFont(), this);
            if(itemSize.width + curX >= this.width - legendMarginHoriz
            && curX > legendMarginHoriz) {
                curY += rowHeight;
                rowStartIndex++;
                curX = rowStarts[rowStartIndex];
                nextX = curX;
            }

            drawLegendElem(curX, curY, plot, rowHeight);
            curX += itemSize.width + legendMarginHoriz;
        }
    }

    void drawLegendImplLeftRight() {
        int nRows;
        foreach(plot; plotData) {
            if(plot.legendText().length) nRows++;
        }

        immutable measurements = measureLegend();
        immutable rowHeight = (measurements.height / measurements.nRows);

        double curY = this.height / 2 - nRows * rowHeight / 2;
        immutable loc = legendLocation();
        immutable x = (loc == LegendLocation.left) ? 10 :
            (this.width - measurements.width - 10);

        foreach(plot; plotData) if(plot.legendText().length) {
            drawLegendElem(x, curY, plot, rowHeight);
            curY += rowHeight;
        }
    }

    void drawLegendElem(double curX, double curY, Plot plot, double rowHeight) {
        immutable textSize = measureText(plot.legendText(), legendFont());
        assert(textSize.height <= rowHeight);

        immutable stdLetterHeight = measureText("A", legendFont()).height;
        immutable textX = curX + legendSymbolSize + legendSymbolTextSpace;
        auto textRect = PlotRect(
            textX,
            curY + rowHeight / 2 - stdLetterHeight / 2,
            textSize.width,
            textSize.height
        );
        drawText(plot.legendText(), legendFont(), getColor(0, 0, 0), textRect,
            TextAlignment.Left);

        auto ySlack = (stdLetterHeight - legendSymbolSize) / 2;
        auto where = PlotRect(
            curX, curY + rowHeight / 2 - legendSymbolSize / 2,
            legendSymbolSize, legendSymbolSize
        );
        plot.drawLegendSymbol(this, where);
    }

    // Controls the space between a tick line and the tick label.
    enum lineLabelSpace = 2;

    void drawXTick(double where, string text, Color color) {
        immutable wherePixels = toPixelsX(where);
        drawLine(
            axesPen,
            PlotPoint(wherePixels, this.height - bottomMargin),
            PlotPoint(wherePixels, this.height - bottomMargin + tickPixels)
        );

        if(verticalGrid()) {
            drawLine(gridPen,
                PlotPoint(wherePixels, topMargin),
                PlotPoint(wherePixels, this.height - bottomMargin));
        }

        if(nullOrInit(_axesFont)) {
            return;
        }

        auto format = TextAlignment.Center;

        immutable textSize = measureText(text, _axesFont, format);
        immutable tickTextStart =
            this.height - bottomMargin  + tickPixels + lineLabelSpace;

        if(rotatedXTick()) {
            auto rect = PlotRect(wherePixels - tickLabelHeight / 2,
                tickTextStart + tickPixels / 2,
                textSize.height,
                textSize.width
            );

            drawRotatedText(text, _axesFont, color, rect, format);
        } else {
            auto rect = PlotRect(wherePixels - textSize.width / 2,
                tickTextStart,
                textSize.width,
                textSize.height
            );

            drawText(text, _axesFont, color, rect, format);
        }
    }

    void drawYTick(double where, string text, Color color) {
        immutable wherePixels = this.height - toPixelsY(where);
        drawLine(
            axesPen,
            PlotPoint(leftMargin, this.height - wherePixels),
            PlotPoint(leftMargin - tickPixels, this.height - wherePixels)
        );

        if(nullOrInit(_axesFont)) {
            return;
        }

        if(horizontalGrid()) {
            drawLine(
                gridPen,
                PlotPoint(leftMargin, this.height - wherePixels),
                PlotPoint(this.width - rightMargin, this.height - wherePixels));
        }

        auto format = TextAlignment.Right;

        immutable textSize = measureText(text, _axesFont, format);
        if(rotatedYTick()) {
            auto rect = PlotRect(
                leftMargin - textSize.height - tickPixels - lineLabelSpace,
                this.height - wherePixels - textSize.width / 2,
                textSize.height,
                textSize.width
            );

            drawRotatedText(text, _axesFont, color, rect, format);
        } else {
            auto rect = PlotRect(
                leftMargin - textSize.width - tickPixels - lineLabelSpace,
                this.height - wherePixels - textSize.height / 2,
                textSize.width,
                textSize.height
            );

            drawText(text, _axesFont, color, rect, format);
        }
    }

    // Used in setupAxes() via delegate.
    double marginSizeX() {
        return leftMargin;
    }

    // Used in setupAxes() via delegate.
    double marginSizeY() {
        return topMargin + bottomMargin;
    }

    void setupAxes(
        double lower,
        double upper,
        ref double[] axisLocations,
        ref string[] axisText,
        double axisSize,
        ref double labelSize,
        double delegate() marginSize
    )
    in {
        assert(upper > lower, std.conv.text(lower, '\t', upper));
    } body {

        immutable diff = upper - lower;

        double tickWidth = 10.0 ^^ floor(log10(diff));
        if(diff / tickWidth < 2) {
            tickWidth /= 10;
        }

        if(diff / tickWidth > 9) {
            tickWidth *= 2;
        }


        if(diff / tickWidth < 4) {
            tickWidth /= 2;
        }

        void updateAxes() {
            double startPoint = ceil(lower / tickWidth) * tickWidth;

            // The tickWidth * 0.01 is a fudge factor to make the last tick
            // get drawn in the presence of rounding error.
            axisLocations = array(
                iota(startPoint, upper + tickWidth * 0.01, tickWidth)
            );

            axisText = doublesToStrings(axisLocations);
            fixMargins();
        }

        do {
            updateAxes();

            // Prevent labels from running together on small plots.
            if((axisSize - marginSize()) / axisLocations.length < labelSize * 4
               && diff / tickWidth > 2) {
                tickWidth *= 2;
                continue;
            } else {
                break;
            }
        } while(true);

        // Force at least two ticks come hell or high water.
        while(axisLocations.length < 2) {
            tickWidth /= 2;
            updateAxes();
        }
    }

    void setLim(
        double lower,
        double upper,
        ref double oldLower,
        ref double oldUpper,
    ) {
        enforce(upper > lower, "Can't have upper limit < lower limit.");
        oldLower = lower;
        oldUpper = upper;
    }

    void nullFontsToDefaults() {
        if(nullOrInit(titleFont())) {
            _titleFont = getFont(plot2kill.util.defaultFont, 14 + fontSizeAdjust);
        }
        if(nullOrInit(xLabelFont())) {
            _xLabelFont = getFont(plot2kill.util.defaultFont, 14 + fontSizeAdjust);
        }

        if(nullOrInit(yLabelFont())) {
            _yLabelFont = getFont
                (plot2kill.util.defaultFont, 14 + fontSizeAdjust);
        }

        if(nullOrInit(axesFont())) {
            _axesFont = getFont(plot2kill.util.defaultFont, 12 + fontSizeAdjust);
        }

        if(nullOrInit(legendFont())) {
            _legendFont = getFont(plot2kill.util.defaultFont, 12 + fontSizeAdjust);
        }
    }

    static bool isValidPlot(Plot plot) {
        if(plot is null) {
            return false;
        }

        return plot.leftMost <= plot.rightMost &&
            plot.bottomMost <= plot.topMost;
    }

package:

    this() {}

    this(Plot[] plots...) {
        this();
        addPlot!(Figure)(plots);
    }

    // These goodies need to be known by various GUI-related code, but end
    // users have no business fiddling with them.
    Plot[] plotData;

    double[] xAxisLocations;
    string[] xAxisText;

    double[] yAxisLocations;
    string[] yAxisText;

    double topMargin = 10;
    double bottomMargin = 10;
    double leftMargin = 10;
    double rightMargin = 30;

public:

    override int defaultWindowWidth() {
        return 800;
    }

    override int defaultWindowHeight() {
        return 600;
    }

    override int minWindowWidth() {
        return 400;
    }

    override int minWindowHeight() {
        return 300;
    }

    // These drawing commands aren't documented for now b/c they're subject
    // to change.

    // Returns whether any part of the rectangle is on screen.
    bool clipRectangle(ref double x, ref double y, ref double width, ref double height) {
        // Do clipping.
        auto bottom = y + height;
        auto right = x + width;
        if(x < leftMargin) {
            x = leftMargin;
        }
        if(right > this.width - rightMargin) {
            right = this.width - rightMargin;
        }

        if(y < topMargin) {
            y = topMargin;
        }

        if(bottom > this.height - bottomMargin) {
            bottom = this.height - bottomMargin;
        }

        width = right - x;
        height = bottom - y;
        return width > 0 && height > 0;
    }

    // Convenience
    static bool between(T, U, V)(T num, U lower, V upper) {
        return lower <= num && num <= upper;
    }

    bool clipLine(ref double x1, ref double y1, ref double x2, ref double y2) {
        immutable topPixel = topMargin;
        immutable bottomPixel = this.height - bottomMargin - 1;
        immutable leftPixel = leftMargin + 1;
        immutable rightPixel = this.width - rightMargin;
        if(between(x1, leftPixel, rightPixel) &&
           between(x2, leftPixel, rightPixel) &&
           between(y1, topPixel, bottomPixel) &&
           between(y2, topPixel, bottomPixel)) {

            return true;
        }

        // Handle slope of zero or infinity as a special case.
        if(x1 == x2) {
            if(!between(x1, leftPixel, rightPixel)) {
                return false;
            } else if(y1 < topPixel && y2 < topPixel) {
                return false;
            } else if(y1 > bottomPixel && y2 > bottomPixel) {
                return false;
            }

            y1 = max(y1, topPixel);
            y1 = min(y1, bottomPixel);
            y2 = max(y2, topPixel);
            y2 = min(y2, bottomPixel);
            return true;
        } else if(y1 == y2) {
            if(!between(y1, topPixel, bottomPixel)) {
                return false;
            } else if(x1 < leftPixel && x2 < leftPixel) {
                return false;
            } else if(x1 > rightPixel && x2 > rightPixel) {
                return false;
            }

            x1 = max(x1, leftPixel);
            x1 = min(x1, rightPixel);
            x2 = max(x2, leftPixel);
            x2 = min(x2, rightPixel);
            return true;
        }

        immutable slope = (y2 - y1) / (x2 - x1);
        enum tol = 0;  // Compensate for rounding error.

        void fixX(ref double x, ref double y) {
            if(x < leftPixel) {
                immutable diff = leftPixel - x;
                x = leftPixel;
                y = diff * slope + y;
            } else if(x > rightPixel) {
                immutable diff = rightPixel - x;
                x = rightPixel;
                y = diff * slope + y;
            }
        }

        void fixY(ref double x, ref double y) {
            if(y < topPixel) {
                immutable diff = topPixel - y;
                y = topPixel;
                x = diff / slope + x;
            } else if(y > bottomPixel) {
                immutable diff = bottomPixel - y;
                y = bottomPixel;
                x = diff / slope + x;
            }
        }
        fixX(x1, y1);
        fixX(x2, y2);
        fixY(x1, y1);
        fixY(x2, y2);

        // This prevents weird rounding artifacts where a line appears as a
        // single point on the edge of the figure.
        if(y1 == y2 && x1 == x2 && (
            (y1 == topPixel || y1 == bottomPixel) ||
            (x1 == leftPixel || x1 == rightPixel))) {
            return false;
        }

        // The minuses and pluses are to deal w/ rounding error.
        return between(x1, leftPixel - tol, rightPixel + tol) &&
               between(x2, leftPixel - tol, rightPixel + tol) &&
               between(y1, topPixel - tol, bottomPixel + tol) &&
               between(y2, topPixel - tol, bottomPixel + tol);
    }

    void drawClippedRectangle
    (Pen pen, double x, double y, double width, double height) {
        if(clipRectangle(x, y, width, height)) {
            drawRectangle(pen, x, y, width, height);
        }
    }

    void drawClippedRectangle(Pen pen, PlotRect r) {
        drawClippedRectangle(pen, r.x, r.y, r.width, r.height);
    }

    void fillClippedRectangle
    (Brush brush, double x, double y, double width, double height) {
        if(clipRectangle(x, y, width, height)) {
            fillRectangle(brush, x, y, width, height);
        }
    }

    void fillClippedRectangle(Brush brush, PlotRect rect) {
        fillClippedRectangle(brush, rect.x, rect.y, rect.width, rect.height);
    }

    void drawClippedLine(Pen pen, PlotPoint from, PlotPoint to) {
        auto x1 = from.x;
        auto y1 = from.y;
        auto x2 = to.x;
        auto y2 = to.y;
        immutable shouldDraw = clipLine(x1, y1, x2, y2);

        if(!shouldDraw) {
            return;
        }

        drawLine(pen, PlotPoint(x1, y1), PlotPoint(x2, y2));
    }

    bool insideAxes(PlotPoint point) {
        if(between(point.x, leftMargin, this.width - rightMargin) &&
           between(point.y, topMargin, this.height - bottomMargin)) {
               return true;
        } else {
            return false;
        }
    }

    void drawClippedText(string text, Font font,
        Color pointColor, PlotRect rect) {

        // To avoid cutting points off of scatter plots, this function only
        // checks whether the center of each point is on the graph.  Therefore,
        // it may allow points to extend slightly off the graph.  This is
        // annoying, but there's no easy way to fix it w/o risking cutting off
        // points.
        immutable xMid = rect.x + rect.width / 2;
        immutable yMid = rect.y + rect.height / 2;

        if(insideAxes(PlotPoint(xMid, yMid))) {
            drawText(text, font, pointColor, rect);
        }
    }

    ///
    final Font axesFont()() {
        return _axesFont;
    }

    ///
    final This axesFont(this This)(Font newFont) {
        _axesFont = newFont;
        return cast(This) this;
    }

    ///
    final Font legendFont()() {
        return _legendFont;
    }

    ///
    final This legendFont(this This)(Font newFont) {
        _legendFont = newFont;
        return cast(This) this;
    }

    ///
    static Figure opCall()() {
        return new Figure;
    }

    /**Convenience factory that adds all plots provided to the Figure.*/
    static Figure opCall(P)(P[] plots)  if(is(P : Plot)) {
        return new Figure(cast(Plot[]) plots);
    }
    
    /// Ditto
    static Figure opCall(P...)(P plots) 
    if(allSatisfy!(isPlot, P)) {
        Plot[plots.length] arr;
        foreach(i, p; plots) arr[i] = p;
        return opCall(arr[]);
    }        

    /**Manually set the X axis limits.
     */
    final This xLim(this This)(double newLower, double newUpper) {
        setLim(newLower, newUpper, leftLim, rightLim);
        return cast(This) this;
    }

    /**Manually set the Y axis limits.
     */
    This yLim(this This)(double newLower, double newUpper) {
        setLim(newLower, newUpper, lowerLim, upperLim);
        return cast(This) this;
    }

    /**
    Set the zoom back to the default value, i.e. just large enough to fit
    everything on the screen.
    */
    This defaultZoom(this This)() {
        upperLim = -double.infinity;
        lowerLim = double.infinity;
        leftLim = double.infinity;
        rightLim = -double.infinity;

        foreach(plot; plotData) {
            upperLim = max(upperLim, plot.topMost);
            rightLim = max(rightLim, plot.rightMost);
            leftLim = min(leftLim, plot.leftMost);
            lowerLim = min(lowerLim, plot.bottomMost);
        }

        return cast(This) this;
    }

    /**Set the X axis labels.  If text is null (default) the axis text is
     * just the text of the axis locations.  R should be any range with
     * length identical to text (unless text is null) and elements implicitly
     * convertible to double.  If colors is empty, all labels will be made
     * black.  Otherwise it must be the same length as locations.
     */
    This xTickLabels(R, this This)
    (R locations, const string[] text = null, Color[] colors = null)
    if(isInputRange!R && is(ElementType!R : double)) {
        userSetXAxis = true;
        xAxisLocations = toDoubleArray(locations);
        enforce(colors.length == xAxisLocations.length || colors.length == 0);
        this._xTickColors = colors.dup;

        if(text.length > 0) {
            enforce(text.length == xAxisLocations.length,
                "Length mismatch between X axis locations and X axis text.");
            xAxisText = text.dup;
        } else {
            xAxisText = doublesToStrings(xAxisLocations);
        }

        return cast(This) this;
    }

    /**
    Resets the X tick labels to the default, effectively undoing a call to
    xTickLabels.
    */
    This defaultXTick(this This)() {
        userSetXAxis = false;
        return cast(This) this;
    }

    /**Set the Y axis labels.  If text is null (default) the axis text is
     * just the text of the axis locations.  R should be any range with
     * length identical to text (unless text is null) and elements implicitly
     * convertible to double.  If colors is empty, all labels will be made
     * black.  Otherwise it must be the same length as locations.
     */
    This yTickLabels(R, this This)
    (R locations, const string[] text = null, Color[] colors = null)
    if(isInputRange!R && is(ElementType!R : double)) {
        userSetYAxis = true;
        yAxisLocations = toDoubleArray(locations);
        enforce(colors.length == xAxisLocations.length || colors.length == 0);
        this._yTickColors = colors.dup;

        if(text.length > 0) {
            enforce(text.length == yAxisLocations.length,
                "Length mismatch between Y axis locations and Y axis text.");
            yAxisText = text.dup;
        } else {
            yAxisText = doublesToStrings(yAxisLocations);
        }

        return cast(This) this;
    }

    /**
    Resets the X tick labels to the default, effectively undoing a call to
    xTickLabels.
    */
    This defaultYTick(this This)() {
        userSetYAxis = false;
        return cast(This) this;
    }

    /**Determines whether vertical gridlines are drawn.  Default is false.*/
    bool verticalGrid()() {
        return _verticalGrid;
    }

    ///
    This verticalGrid(this This)(bool val) {
        this._verticalGrid = val;
        return cast(This) this;
    }

    /**Determines whether horizontal gridlines are drawn.  Default is false.*/
    bool horizontalGrid()() {
        return _horizontalGrid;
    }

    ///
    This horizontalGrid(this This)(bool val) {
        this._horizontalGrid = val;
        return cast(This) this;
    }

    /// Grid intensity from zero (pure white) to 255 (pure black).
    ubyte gridIntensity()() {
        return _gridIntensity;
    }

    /// Setter.
    This gridIntensity(this This)(ubyte newIntensity) {
        _gridIntensity = newIntensity;
        return cast(This) this;
    }

    ///
    LegendLocation legendLocation()() {
        return _legendLoc;
    }

    ///
    This legendLocation(this This)(LegendLocation newLoc) {
        this._legendLoc = newLoc;
        return cast(This) this;
    }

    /**
    Determines whether rotated text is used for the X tick labels.
    */
    final bool rotatedXTick()() {
        return _rotatedXTick;
    }

    /// Setter
    final This rotatedXTick(this This)(bool newVal) {
        _rotatedXTick = newVal;
        return cast(This) this;
    }

    /**
    Determines whether rotated text is used for the Y tick labels.
    */
    final bool rotatedYTick()() {
        return _rotatedYTick;
    }

    /// Setter
    final This rotatedYTick(this This)(bool newVal) {
        _rotatedYTick = newVal;
        return cast(This) this;
    }

    /**The leftmost point on the figure.*/
    double leftMost()  {
        return leftLim;
    }

    /**The rightmost point on the figure.*/
    double rightMost()  {
        return rightLim;
    }

    /**The topmost point on the figure.*/
    double topMost()  {
        return upperLim;
    }

    /**The bottommost point on the figure.*/
    double bottomMost()  {
        return lowerLim;
    }

    /**Add individual lines to the figure.  Coordinates are specified relative
     * to the plot area, not in pixels.  The lines are is clipped
     * to the visible part of the plot area.  This is useful for adding
     * annotation lines, as opposed to plot lines.
     */
    This addLines(this This)(FigureLine[] lines...) {
        extraLines ~= lines;
        return cast(This) this;
    }

    /**Add one or more plots to the figure.*/
    This addPlot(this This)(Plot[] plots...) {
        foreach(plot; plots) {
            if(!isValidPlot(plot)) {
                continue;
            }

            upperLim = max(upperLim, plot.topMost);
            rightLim = max(rightLim, plot.rightMost);
            leftLim = min(leftLim, plot.leftMost);
            lowerLim = min(lowerLim, plot.bottomMost);
            plotData ~= plot;
        }

        return cast(This) this;
    }
//    
//    /// Ditto
//    This addPlot(this This, P...)(P plots)
//    if(allSatisfy!(isPlot, P)) {
//        Plot[plots.length] arr;
//        foreach(i, elem; plots) arr[i] = elem;
//        return addPlot(arr[]);
//    }

    /**
    Remove one or more plots from the figure.  If the plots are not in the
    figure, they are silently ignored.
    */
    This removePlot(this This)(Plot[] plots...) {
        void removePlotImpl(Plot p) {
            auto plotIndex = countUntil!"a is b"(plotData, p);
            if(plotIndex == -1) return;
            plotData = plotData[0..plotIndex] ~ plotData[plotIndex + 1..$];
        }

        foreach(p; plots) {
            removePlotImpl(p);
        }

        upperLim = reduce!max(-double.infinity, map!"a.topMost"(plotData));
        lowerLim = reduce!min(double.infinity, map!"a.bottomMost"(plotData));
        rightLim = reduce!max(-double.infinity, map!"a.rightMost"(plotData));
        leftLim = reduce!min(double.infinity, map!"a.leftMost"(plotData));

        return cast(This) this;
    }

    /**Draw the plot but don't display it on screen.*/
    override void drawImpl() {
        auto whiteBrush = getBrush(getColor(255, 255, 255));
        fillRectangle(whiteBrush, 0, 0, this.width, this.height);
        doneWith(whiteBrush);
        // If this is not a valid Figure, leave a big blank white rectangle.
        // It beats crashing.
        if(!(leftLim < rightLim && lowerLim < upperLim)) {
            return;
        }
        axesPen = getPen(getColor(0, 0, 0), 2);
        scope(exit) doneWith(axesPen);

        auto notGridIntens = cast(ubyte) (ubyte.max - gridIntensity());
        gridPen = getPen(
            getColor(notGridIntens, notGridIntens, notGridIntens), 1
        );
        scope(exit) doneWith(gridPen);

        nullFontsToDefaults();

        if(!userSetXAxis) {
            setupAxes(leftLim, rightLim, xAxisLocations, xAxisText,
                this.width, xTickLabelWidth, &marginSizeX);
        }

        if(!userSetYAxis) {
            setupAxes(lowerLim, upperLim, yAxisLocations, yAxisText,
                this.height, tickLabelHeight, &marginSizeY);
        }

        fixMargins();
        drawTicks();

        foreach(plot; plotData) {
            if(!isValidPlot(plot)) {
                continue;
            }

            immutable x = toPixelsX(plot.leftMost);
            immutable y = toPixelsY(plot.topMost);
            immutable subHeight = toPixelsY(plot.bottomMost) - y;
            immutable subWidth = toPixelsX(plot.rightMost) - x;
            plot.drawPlot(this, x, y, subWidth, subHeight);
        }

        drawYlabel();
        drawExtraLines();
        drawAxes();
        drawTitle();
        drawXlabel();
        drawLegend();
    }

    version(none) {
    void showUsingImplicitMain() {
        ImplicitMain.initialize();
        ImplicitMain.addForm(this);
    }
    }
}

///
enum LegendLocation {
    ///
    top,

    ///
    bottom,

    ///
    left,

    ///
    right
}

/**For drawing extra lines on a Figure, with coordinates specified in plot
 * units and relative to the plot area, not in pixels.*/
struct FigureLine {
private:
    double x1;
    double y1;
    double x2;
    double y2;
    Color lineColor;
    uint lineWidth = 1;

public:
    this(double x1, double y1, double x2,
         double y2, Color lineColor, uint lineWidth = 1) {

        enforce(isFinite(x1) && isFinite(x2) && isFinite(y1) && isFinite(y2),
                "Line coordinates must be finite.");
        this.x1 = x1;
        this.y1 = y1;
        this.x2 = x2;
        this.y2 = y2;
        this.lineColor = lineColor;
        this.lineWidth = lineWidth;
    }
}

/**
Most of these classes copy their input data into a double[] by default.  Use
this to signal that copying is unnecessary.  The range primitives just forward
to data.
*/
struct NoCopy {
    ///
    double[] data;

    ///
    double front() @property { return data.front; }

    ///
    void popFront() { data.popFront(); }

    ///
    bool empty() @property { return data.empty; }

    ///
    typeof(this) save() @property { return this; }

    ///
    double opIndex(size_t index) { return data[index]; }

    ///
    typeof(this) opSlice(size_t lower, size_t upper) {
        return NoCopy(data[lower..upper]);
    }
}

private template isPlot(P) { enum isPlot = is(P : Plot); }
