#!/usr/bin/env python
# -*- coding: utf-8 -*- #

from __future__ import unicode_literals
import os

AUTHOR = u'Ivan Minčík'
SITENAME = u'GIS.lab'
SITESUBTITLE = u'... total reduction of deployment and maintenance costs for complete geospatial infrastructure'
SITEURL = ''

TIMEZONE = 'Europe/Bratislava'

DEFAULT_LANG = u'en'

# Feed generation is usually not desired when developing
FEED_ALL_ATOM = None
CATEGORY_FEED_ATOM = None
TRANSLATION_FEED_ATOM = None

# Blogroll
LINKS =  (
	('Mailing list', 'http://lists.osgeo.org/cgi-bin/mailman/listinfo/gis.lab'),
	('IRC', 'http://webchat.freenode.net/?channels=%23gis.lab&uio=d4'),
	('GISMentors.eu', 'http://www.gismentors.eu'),
)

# Social widget
#SOCIAL = (('You can add links in your config file', '#'),
#          ('Another social link', '#'),)

DISPLAY_PAGES_ON_MENU = True
DEFAULT_PAGINATION = 10

MD_EXTENSIONS = ['codehilite(css_class=highlight)', 'extra']

THEME = os.path.join(os.path.abspath(os.curdir), "themes/blueidea")
DISPLAY_CATEGORIES_ON_MENU = True
PAGES_SORT_ATTRIBUTE = 'order'
GITHUB_URL = 'http://web.gislab.io'

STATIC_PATHS = [
	'robots.txt',
	'images',
	'extra/CNAME',
]
EXTRA_PATH_METADATA = {'extra/CNAME': {'path': 'CNAME'},}


# Uncomment following line if you want document-relative URLs when developing
RELATIVE_URLS = True
