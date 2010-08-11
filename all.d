/**Convenience module that simply publicly imports everything else.
 *
 * License:
 *
 * The author believes this module is not original enough to be
 * copyrightable.  Therefore, no license is necessary.
 */

module plot2kill.all;

public import plot2kill.figure, plot2kill.subplot, plot2kill.guiagnosticbase;

version(dfl) {
    public import plot2kill.dflwrapper;
} else version(gtk) {
    public import plot2kill.gtkwrapper;
}

