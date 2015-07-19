package uk.org.opentrv.comms.util;

/**Common sensor (printable ASCII-7 single-letter) types/labels.
 * Includes the label, and (en-gb) description.
 */
public enum CommonSensorLabels
    {
    ID('@', "node/sensor ID"),
    BATTERY('B', "battery voltage"),
    LIGHT('L', "ambient light"),
    HUMIDITY('H', "relative humidity"),
    POWERLOW('P', "power warning"),
    TEMPERATURE('T', "temperature"),
    ;

    private final char label;
    /**Get (printable ASCII-7 single-letter) type/label. */
    public char getLabel() { return(label); }

    private final String description;
    /**Get (printable ASCII-7 en-gb) description. */
    public String getDescription() { return(description); }

    private CommonSensorLabels(final char label, final String description)
        {
        if((label < 32) || (label > 126)) { throw new IllegalArgumentException(); }
        if(null == description) { throw new IllegalArgumentException(); }
        this.label = label;
        this.description = description;
        }
    }
