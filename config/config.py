global html
import html
import os

worlds["minecraft"] = "/home/minecraft/server/world"
outputdir = "/home/minecraft/render/"

renders["day"] = {
    "title": "Day",
    "dimension": "overworld",
    "rendermode": "smooth_lighting",
    "world": "minecraft",
    "crop": (-10000, -10000, 10000, 10000),
}
