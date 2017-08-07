# coding utf-8

from pydocx.export import PyDocXHTMLExporter
from pydocx.export.html import HtmlTag

class PyDocXHTMLExporterUnderline(PyDocXHTMLExporter):

    def export_run_property_underline(self, run, results):
        tag = HtmlTag('u')
        return self.export_run_property(tag, run, results)


html = PyDocXHTMLExporterUnderline('./huizhi.docx').export()

with open('output.html', 'w') as output:
    output.write(html)