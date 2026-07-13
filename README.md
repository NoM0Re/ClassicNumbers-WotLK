<div align="center">

# ClassicNumbers WotLK (3.3.5a)

[![Discord](https://img.shields.io/discord/259362419372064778?style=flat&logo=discord&label=Discord)](https://discord.gg/UXSc7nt) [![GitHub Issues](https://img.shields.io/github/issues/NoM0Re/ClassicNumbers-WotLK)](https://github.com/NoM0Re/ClassicNumbers-WotLK/issues) [![PayPal](https://img.shields.io/badge/Buy_me_a_coffee-100000?style=flat&logo=PayPal&logoColor=white&labelColor=3b7bbf&color=grey)](https://streamelements.com/nom0ree/tip)

**Vanilla style damage popping animation for 3.3.5a WotLK**

<img src="https://i.ibb.co/DPYcKx5Z/cnscreenshot.png">

</div>

## Quick Start

To open the options window, type `/cn` or `/classicnumbers` or `/classicnumber` into your chat and hit enter.

## Options includes:

Enable: enable the mod
Disable Blizzard's numbers: disables the default blizzard's combat text
Truncate numbers: a 1200 hit will be displayed as '1.2k'
Text Size: the font size
Text alpha: the transparency of the text
Text display duration
Text offset: set the text position wherever you like it
Scroll speed: set the non crit text scroll speed
Hide NonCrits if big crit chain: Temporarly hide normal hits if having rapid flow of critical strikes
Small hit filter: choose a number -> non crits will be hidden if the damage is below the chosen number
Small crit filter: choose a number -> crits will be displayed as if it was a non crit if the damage is below the chosen number. They'll still appear bigger than non crits, though, but they won't POP
Max crits displayed per target: only display the X newest crits per target, set to one to have a MOP style where only the latest crit is displayed
Use damage school colors: fire damage will be orange, frost damage will be blue, etc... if disabled, all abilities damage will be yellow"

## Client Support

Enemy nameplates must be enabled for ClassicNumbers to display damage.

### Standard 3.3.5a Client

ClassicNumbers displays damage for nameplates verified through a stable target or mouseover match. It can also learn raid-marked enemies exposed by focus, pet, party/raid-target, boss, or arena unit IDs when one raid icon identifies exactly one GUID and one visible nameplate. Unknown or ambiguous nameplates are intentionally ignored instead of guessing by name or health.

### Awesome WotLK Client

[Awesome WotLK](https://github.com/NoM0Re/WeakAuras-WotLK/wiki/awesome_wotlk) is optional. Its modern nameplate API provides reliable unit tracking, allowing ClassicNumbers to display damage on all visible nameplates.

## Install

1. [Download the package](https://github.com/NoM0Re/ClassicNumbers-WotLK/archive/refs/heads/main.zip).
2. Optionally install [Awesome WotLK](https://github.com/NoM0Re/WeakAuras-WotLK/wiki/awesome_wotlk) for damage numbers on all visible nameplates.
3. Open the archive, then open folder `ClassicNumbers-WotLK-main`, extract the folder to `Interface\AddOns`.

## Problems

* If you've discovered something that's clearly wrong, or if you get an error, please create a [ticket](https://github.com/NoM0Re/ClassicNumbers-WotLK/issues).
