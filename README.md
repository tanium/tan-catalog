The IBM Cloud Tanium Client Deployment tile in the IBM Cloud Catalog is used to install the Tanium Client to an IBM Cloud asset. In order to use this deployment method, you must first perform the following tasks:
1.	Create and download the Tanium client install bundle from your Tanium Server
2.	Create a secure IBM Cloud object storage bucket 
3.	Upload the Tanium client install bundle to the IBM Cloud object storage bucket


### Creating the Tanium client install bundle

1. Login to your Tanium console.
2.	Navigate to the Client Management (Administration->Shared Services->Client Management)
3.	Navigate to Client Settings
4.	Click Create to create a new client setting profile
5.	Enter a Client Setting Name for the profile
6.	Enter the Tanium Server names for your Tanium infrastructure
7.	Select Client Version 7.4.2073 (Note: For the Beta this is the only client version supported by the installation script)
8.	For Client Platforms, remove AIX, MacOS,Solaris and Windows by click on the “X”. This should leave only Linux selected (Note: For the Beta Linux is the only platform supported for the IBM Cloud catalog Tanium client deployment)
9.	Scroll to the bottom of the page and click Save
10.	You should now see the Client Setting Profile you just created.
11.	When the Tanium Client deployment bundle is available for download, the download button will no longer be grayed out.
12.	Click the download button for the newly created Client Settings profile to download the Tanium client install bundle to your local machine. The bundle will be downloaded to your local file system in the form of a zip file. Note the download location.
13.	Extract the zip file to a folder on your local machine.

The Tanium Client install bundle contains the tanium-init.dat file for your Tanium environment and the Tanium Client binaries.

## Create a IBM Cloud Object Storage (COS) bucket
The IBM Cloud Object Storage bucket is used as a repository for your Tanium Client deployment bundle. It is important that the COS bucket is secured based on IBM best practices to prevent unauthorized access to the Tanium Client binaries and your tanium-init.dat file.

1.	Create an IBM Cloud Object Storage bucket
https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage


2.	Secure the Cloud Object Storage access via Service Credentials
https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-service-credentials
 

3.	Grant Access to using the Service Credentials
https://cloud.ibm.com/docs/cloud-object-storage/iam?topic=cloud-object-storage-iam-bucket-permissions


4.	It is highly recommended you disable public access to this COS bucket.
https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-iam-public-access#public-access-console-disable



## Upload the Tanium Client install bundle to your IBM COS bucket
Once you created and secured your IBM COS bucket, you are now ready to upload the Tanium Client installation bundle to your IBM COS bucket. The IBM COS bucket acts as a secure repository for the Tanium Client install script to retrieve the required tanium-init.dat file and the appropriate Tanium Client binary for the target IBM Cloud asset via the IBM Cloud catalog tile.

1.	Login to your IBM Cloud account
2.	From your main Dashboard view, in your Resource summary, select the Storage link.
3.	From the Resource List view, scroll down to locate the cloud object storage resource created in the previous task, click the COS resource.
4.	In the Buckets view,  select the COS bucket you will use to upload the Tanium Client  install bundle.
5.	On the Objects page, expand on the Upload drop down menu and select Folders.
6.	Navigate to the folder containing the extracted Tanium Client install bundle on your local file system and select it and click open to perform the upload.
7.	Once the Tanium Client install bundle is successfully uploaded, make note of the full file path in the COS bucket. This will be required input during the deployment process.



# Create instance from catalog

## Configure your workspace
1. Give the workspace an appropriate name
2. Select the appropriate `Resource group`
3. Apply tags if needed

## Set the deployment values

* client_ipv4_address
    * The IP address of the machine to install Tanium client on
* cos_bucket_apikey
    * The API key to access the bucket
    * To find:
        * Navigate to the COS instance where the bucket is located
        * Click `Service credentials`
        * Clik the arrow next to the name of the bucket that has the dat file
        * Copy the `apikey`
* dcos_bucket_endpoint
    * The public endpoint of the COS bucket
    * To find:
        * Navigate to the bucket that has the dat file
        * Click the `More options` button for the dat file
        * Click `Object Details`
        * Find the `Object SQL URL`
        * Copy everything from the bucket's name to the end of the dat file's name
* private_key
    * The private key that is associated with the VM
* server_ipv4_address
    * The IP address of the Tanium server to connect to
* tanium_client_files_folder
    * The path to the folder in the COS bucket

