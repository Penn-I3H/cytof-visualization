import sys
import shutil
import os, os.path
import pdfkit
import datetime
import pytz
import subprocess

try:
    output = subprocess.run(["Rscript", "/service/R/main.R"]) 
except subprocess.CalledProcessError as e:
    print(f"command failed with return code {e.returncode}")

print("Generating report ...")

src = os.environ['INPUT_DIR']   
dest = os.environ['OUTPUT_DIR']    

# create report - pdfkit
banner = "/service/I3H_Logo_HiRes.jpg"
eastern = pytz.timezone('US/Eastern')
dt = datetime.datetime.now(eastern)
generated = dt.strftime('%Y-%m-%d %H:%M:%S %Z%z')

boxplot_location = f'{dest}/boxplots.png'
cleanup_location = f'{dest}/cleanup.png'
lasso_location = f'{dest}/lasso.png'
umap_location = f'{dest}/umap.png'

proportions_bar_cd4 = f'{dest}/proportions_bar_cd4.png'
proportions_bar_cd8 = f'{dest}/proportions_bar_cd8.png'
proportions_bar_major = f'{dest}/proportions_bar_major.png'
proportions_bar_other = f'{dest}/proportions_bar_other.png'
cv_bar = f'{dest}/cv_bar.png'

# QC All
qc_summary_all = f'{dest}/QC_all/qc_summary.png'
qc_univariate_B_all = f'{dest}/QC_all/qc_univariate_B cell.png'
qc_univariate_Neutrophil_all = f'{dest}/QC_all/qc_univariate_Neutrophil.png'
qc_univariate_T_CD4_all = f'{dest}/QC_all/qc_univariate_T cell CD4.png'
qc_univariate_T_CD8_all = f'{dest}/QC_all/qc_univariate_T cell CD8.png'
# QC Controls
qc_summary_controls = f'{dest}/QC_controls/qc_summary.png'
qc_univariate_all = f'{dest}/QC_controls/qc_univariate_all.png'

# count the files processed
analysed_samples = len([name for name in os.listdir(src) if os.path.isfile(os.path.join(src, name)) and "cleanup_stats" in name])

body = """
    <html>
      <head>
        <meta name="pdfkit-page-size" content="A4"/>
        <meta name="pdfkit-orientation" content="Portrait"/>
      </head>
      <header>
      <img src="{banner}" width="300px">
      </header>
      <body>
      <hr style="width:100%;text-align:left;margin-left:0">
      <div> [ <i>Report Generated : {generated}</i> ]</div>
         <div>
      <i>This report was generated using the Automated CyTOF Data Analysis workflow on the <i>Pennsieve Platform</i>. <br>
      For more information about the results, please contact the Immune Health Data Core (Matei Ionita).</i>
      </div>
      <p>
       Samples were received and processed by the Immune Health (IH) processing unit. Data acquisition was then performed on IH's CyTOF XT instrument and resulted in <u>{analysed_samples} FCS files</u>. 
       The files were analysed on the Pennsieve platform in order to determine QC scores for each file and quantify the abundance of <u>40 immune cell types</u>.
      </p>
   
      <div style="break-after:page"></div>

      <table style="border-collapse: collapse;">
        <tr>
            <td><h2>1. Cleanup</h2></td>
        </tr>

        <tr>
        <td>As a first step, each file was filtered using six successive bivariate gates, to exclude beads, dead cells and other outliers.</td>
        </tr>
        
        <tr style='padding-bottom:50px'>
            <td>
            <img width="900px" src="{cleanup_location}"></br></br>
            <div><u>Figure 1</u>: Event counts at each stage in the cleanup process. Files with a high percentage of events removed during the cleanup process or those with very few viable events remaining, are highlighted.</div>
            </td>
        </tr>
        </table>

        <div style="break-after:page"></div>

        <table style="border-collapse: collapse;">
        <tr>
            <td><h2>2. QC for all files</h2></td>
        </tr>
        <tr>
        <td>As a quality control measure, the distribution of protein expression in 4 main cell types was compared across all files. Files with aberrant or unusual distributions were flagged and manually reviewed.</td>
        </tr>
        </br></br>
        <tr>
        <td><textarea name="comments" id="comments" cols="75" rows="10">Comments:</textarea></td>
        </tr>
        <tr style='padding-bottom:50px'>
            <td>
            <div style="text-align: center;"><img style="max-width: 25%; object-fit: contain;" src="{qc_summary_all}"></div></br></br>
            <div><u>Figure 2</u>: Heatmap showing QC statusus by major cell type in all files. Files with outlying protein expression distribution are shown in red, while those in which certain cell types were insufficiently abundant to estimate distributions are show in gray.</div>
            </td>
        </tr>
        </table>

        <div style="break-after:page"></div>

        <table style="border-collapse: collapse;">
        <tr style='padding-bottom:50px'>
            <div style="text-align: center;"><img style="max-width: 55%; object-fit: contain;" src="{qc_univariate_B_all}"></div></br></br>
            <div><u>Figure 3</u>: Estimates of the distribution of protein expression in B cells. Each curve represents the distribution of cells in one file, with files flagged for QC displayed in red.</div>
            </td>
        </tr>
        <tr style='padding-bottom:50px'>
            <td>
            <div style="text-align: center;"><img style="max-width: 55%; object-fit: contain;" src="{qc_univariate_Neutrophil_all}"></div></br></br>
            <div><u>Figure 4</u>: Estimates of the distribution of protein expression in Neutrophils. Each curve represents the distribution of cells in one file, with files flagged for QC displayed in red.</div>
            </td>
        </tr>
        </table>

        <div style="break-after:page"></div>

        <table style="border-collapse: collapse;">
        <tr style='padding-bottom:50px'>
            <td>
            <div style="text-align: center;"><img style="max-width: 55%; object-fit: contain;" src="{qc_univariate_T_CD4_all}"></div></br></br>
            <div><u>Figure 5</u>: Estimates of the distribution of protein expression in CD4 T cells. Each curve represents the distribution of cells in one file, with files flagged for QC displayed in red.</div>
            </td>
        </tr>
        <tr style='padding-bottom:50px'>
            <td>
            <div style="text-align: center;"><img style="max-width: 55%; object-fit: contain;" src="{qc_univariate_T_CD8_all}"></div></br></br>
            <div><u>Figure 6</u>: Estimates of the distribution of protein expression in CD8 T cells. Each curve represents the distribution of cells in one file, with files flagged for QC displayed in red.</div>
            </td>
        </tr>
        </table>

        <div style="break-after:page"></div>

        <table style="border-collapse: collapse;">
        <tr>
            <td><h2>3. QC for technical control files</h2></td>
        </tr>
        <tr>
        <td>Alongside the study samples, technical control replicates were run in each day of acquisition, to measure the consistency of the instrument across data acquisition batches. We measured the consistency of protein expression distribution across the replicates.</td>
        </tr>
        <tr style='padding-bottom:50px'>
            <td>
            <div style="text-align: center;"><img width="900px" src="{qc_summary_controls}"></div>
            </br></br>
            <div><u>Figure 7</u>: Heatmap showing QC status by major cell type in technical control  files. Files with outlying protein expression distribution are shown in red, while those in which certain cell types were insufficiently abundant to estimate distributions are show in gray.</div>
            </td>
        </tr>
        </table>

        <div style="break-after:page"></div>

        <table style="border-collapse: collapse;">
        <tr style='padding-bottom:50px'>
            <td>
            <div style="text-align: center;"><img style="max-width: 75%; object-fit: contain;" src="{qc_univariate_all}"></div></br></br>
            <div><u>Figure 8</u>: Estimates of the distribution of protein expression in all viable events in technical control files. Each curve represents the distribution of cells in one file, with files flagged for QC displayed in red.</div>
            </td>
        </tr>
        </table>

        <div style="break-after:page"></div>

        <table style="border-collapse: collapse;">
        <tr>
            <td><h2>4. Cell type porportions</h2></td>
        </tr>
        <tr style='padding-bottom:50px'>
            <td>
            <div><img style="max-width: 75%; object-fit: contain;" src="{proportions_bar_major}"></div></br></br>
            <div><u>Figure 9</u>: Cell type proportions of major cell types by file.</div>
            </td>
        </tr>
        <tr style='padding-bottom:50px'>
            <td>
            <div ><img style="max-width: 75%; object-fit: contain;" src="{proportions_bar_cd4}"><div></br></br>
            <div><u>Figure 10</u>: Cell type porportions of CD4 T cell subsets by file.</div>
            </td>
        </tr>
        </table>

        <div style="break-after:page"></div>

        <table style="border-collapse: collapse;">
        <tr style='padding-bottom:50px'>
            <td>
            <div ><img style="max-width: 100%; object-fit: contain;" src="{proportions_bar_cd8}"></div>
            </br></br>
            <div><u>Figure 11</u>: Cell type proportions of CD8 T cell and NK cell subsets by file.</div>
            </td>
        </tr>
        <tr style='padding-bottom:50px'>
            <td>
            <div><img style="max-width: 100%; object-fit: contain;" src="{proportions_bar_other}"></div>
            </br></br>
            <div><u>Figure 12</u>: Cell type proportions of B cell and Monocyte subsets by file.</div>
            </td>
        </tr>
        </table>

       <div style="break-after:page"></div>

       <table style="border-collapse: collapse;">
        <tr style='padding-bottom:50px'>
            <td>
            <div><img style="max-width: 100%; object-fit: contain;" src="{cv_bar}"></div>
            </br></br>
            <div><u>Figure 13</u>: Coefficients of variation (lower is better) for cell type proportions across technical replicates. Colors show mean abundance out of parent population.</div>
            </td>
        </tr>
        </table>

       <div style="break-after:page"></div>

        <table style="border-collapse: collapse;">
        <tr>
        <td><textarea name="comments" id="comments" cols="100" rows="50">Comments:</textarea></td>
        </tr>
              <tr>
        <td><textarea name="signature" id="signature" cols="100" rows="10">Signed:</textarea></td>
        </tr>
      </table>

      </body>
      <br>
      <footer><center>I3H, 421 Curie Blvd. Philadelphia, PA 19104</center></footer>
      </html>
    """.format(analysed_samples=analysed_samples, banner=banner, generated=generated, boxplot_location=boxplot_location, cleanup_location=cleanup_location, lasso_location=lasso_location, umap_location=umap_location,
               qc_summary_all=qc_summary_all, qc_univariate_B_all=qc_univariate_B_all, qc_univariate_Neutrophil_all=qc_univariate_Neutrophil_all, qc_univariate_T_CD4_all=qc_univariate_T_CD4_all, qc_univariate_T_CD8_all=qc_univariate_T_CD8_all,
               qc_summary_controls=qc_summary_controls, qc_univariate_all=qc_univariate_all,
               proportions_bar_major=proportions_bar_major, proportions_bar_cd4=proportions_bar_cd4, proportions_bar_cd8=proportions_bar_cd8, proportions_bar_other=proportions_bar_other, cv_bar=cv_bar)

options = {"enable-local-file-access": ""}
pdfkit.from_string(body, f'{dest}/ih-report.pdf', options=options)

print("Report generation complete.")
