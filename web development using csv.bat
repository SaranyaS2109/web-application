public class UploadController : ApiController
    {
        [Route("api/Device/PostUpload")]
        [HttpPost]
        [ActionName("PostUpload")]
        public string PostUpload()
        {
            string individualExtractPath = null;
            StreamReader sr = null;
            try
            {
                HttpRequest request = HttpContext.Current.Request;
                //making file unique,you can use GUID also
                string fileName = request.Files[0].FileName + "_" + DateTime.Now.ToString("yyyy_MM_dd_HH_mm_ss");
                string DeviceId = request.Form["DeviceId"];
                //check for column key id
                if (DeviceId == null || "null".Equals(DeviceId.ToLower()))
                {
                   return "UnRegistered";

                }   
                string strFileExtractPath = HttpRuntime.AppDomainAppPath;
                strFileExtractPath = Path.Combine(strFileExtractPath, "UploadExtract");

                if (!Directory.Exists(strFileExtractPath))
                {
                    Directory.CreateDirectory(strFileExtractPath);
                }

                individualExtractPath = Path.Combine(strFileExtractPath, fileName);
                Directory.CreateDirectory(individualExtractPath);
                request.Files[0].SaveAs(individualExtractPath + "\\" + request.Files[0].FileName);
                string strUnzipedFilesLocation = Path.Combine(individualExtractPath, "unzipedFiles");
                Directory.CreateDirectory(strUnzipedFilesLocation);
                ZipFile.ExtractToDirectory(individualExtractPath + "\\" + request.Files[0].FileName, strUnzipedFilesLocation);
                ArrayList fileList = new ArrayList();
                // Get the files in the Directory
                string[] files = Directory.GetFiles(strUnzipedFilesLocation);

                int len = files.Length;

                for (int i = 0; i < len; i++)
                {
                    string filename = files[i];

                    // Add into the ArrayList
                    fileList.Add(System.IO.Path.GetFileName(filename));
                    FileInfo uploadFile = new FileInfo(filename);
                    sr = new StreamReader(filename);
                    DataTable oDataTable = null;
                    int RowCount = 0;
                    string[] ColumnNames = null;
                    string[] oStreamDataValues = null;
                    //using while loop read the stream data till end
                    while (!sr.EndOfStream)
                    {
                        String oStreamRowData = sr.ReadLine().Trim();
                        if (oStreamRowData.Length > 0)
                        {
                            oStreamDataValues = oStreamRowData.Split(',');
                            //Bcoz the first row contains column names, we will poluate 
                            //the column name by
                            //reading the first row and RowCount-0 will be true only once
                            if (RowCount == 0)
                            {
                                RowCount = 1;
                                ColumnNames = oStreamRowData.Split(',');
                                oDataTable = new DataTable();
                                //using foreach looping through all the column names
                                foreach (string csvcolumn in ColumnNames)
                                {
                                    DataColumn oDataColumn = new DataColumn(csvcolumn.ToUpper(), typeof(string));
                                    //setting the default value of empty.string to newly created column
                                    oDataColumn.DefaultValue = string.Empty;
                                    //adding the newly created column to the table
                                    oDataTable.Columns.Add(oDataColumn);
                                }
                            }
                            else
                            {
                                //creates a new DataRow with the same schema as of the oDataTable            
                                DataRow oDataRow = oDataTable.NewRow();
                                //using foreach looping through all the column names
                                for (int c = 0; c < ColumnNames.Length; c++)
                                {
                                    oDataRow[ColumnNames[c]] = oStreamDataValues[c] == null ? string.Empty : oStreamDataValues[c].ToString();
                                }
                                //adding the newly created row with data to the oDataTable       
                                oDataTable.Rows.Add(oDataRow);
                            }
                        }
                    }
                    //close the oStreamReader object
                    sr.Close();
                    //release all the resources used by the oStreamReader object
                    sr.Dispose();
                    //Creating two additinal columns dynamically because mobile trip file doesn't provide that

               
                    DataTable dtFinal = oDataTable;
                    //Class Bulk Insert here
                    BulkInsertTripFile(oDataTable);

                }

                return "File SuccessFully Posted";
            }
            finally
            {
                try
                {
                  
                    if (!string.IsNullOrEmpty(individualExtractPath) && Directory.Exists(individualExtractPath))
                    {
                        //If any such directory then creates the new one
                        DeleteDirectory(individualExtractPath);
                    }
                }
                catch (Exception ex)
                {
                    throw ex;
                }
            }
        }
        /// <summary>
        /// After uploading file ,just need
        /// </summary>
        /// <param name="target_dir"></param>
        private static void DeleteDirectory(string target_dir)
        {
            string[] files = Directory.GetFiles(target_dir);
            string[] dirs = Directory.GetDirectories(target_dir);

            foreach (string file in files)
            {
                File.SetAttributes(file, FileAttributes.Normal);
                File.Delete(file);
            }

            foreach (string dir in dirs)
            {
                DeleteDirectory(dir);
            }

            Directory.Delete(target_dir, false);
        }
        /// <summary>
        /// Method for Trip Detail bulk insert with datatable as parameter
        /// </summary>
        /// <param name="dt"></param>
        private void BulkInsertTripFile(DataTable dt)
        {

            string connString = System.Configuration.ConfigurationManager.AppSettings["BulkDemo"];

            // Copy the DataTable to SQL Server
            using (SqlConnection dbConnection = new SqlConnection(connString))
            {
                dbConnection.Open();
                using (SqlBulkCopy s = new SqlBulkCopy(dbConnection))
                {
                    s.DestinationTableName = "TripTable";
                    foreach (var column in dt.Columns)
                        s.ColumnMappings.Add(column.ToString(), column.ToString());
                    s.WriteToServer(dt);
                }
            }
        }
    }