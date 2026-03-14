var panel = new Panel();
panel.location = "bottom";
panel.height = 76;

// Content sizing
panel.lengthMode = 1; // FitContent
panel.minimumLength = 0;
panel.maximumLength = 0;
panel.alignment = "center";
panel.hiding = "dodgewindows";

// Disable background SVG rendering for real transparency
panel.writeConfig("backgroundHints", 4);
panel.writeConfig("userBackgroundHints", 4);
panel.writeConfig("opacityMode", 1);
panel.writeConfig("floating", 0);

// Remove default widgets (spacers cause the panel to stretch and redraw the SVG)
var currentWidgets = panel.widgets();
for (var i = 0; i < currentWidgets.length; i++) {
    currentWidgets[i].remove();
}

// Add the task manager widget
panel.addWidget("org.vicko.wavetask");

panel.reloadConfig();
