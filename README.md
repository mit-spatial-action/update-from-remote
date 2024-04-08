# update-from-remote
Lil' utility that pulls the last modified date of a remote file and checks it against previous download in order to determine whether there has been an update on the remote. If the remote has been updated, it downloads the updated file and moves the outdated local copy to an archive folder. Also includes a script to push the updated file to a folder associated with a Dropbox application, which also handles the 150MB payload limit for the base [`upload/`](https://www.dropbox.com/developers/documentation/http/documentation#files-upload) endpont by splitting large files and using the [`upload_session/`](https://www.dropbox.com/developers/documentation/http/documentation#files-upload_session-append) endpoint. Handles all the stuff you'd expect (checking whether files exists on Dropbox before pushing file, etc.).

Currently used to create an archive of the [MassGIS Property Tax Parcels database](https://www.mass.gov/info-details/massgis-data-property-tax-parcels). Archive is available in [this Dropbox folder](https://www.dropbox.com/scl/fo/8tb0boh3ejckizdx3w9q8/h?rlkey=ye2s8zgs16dif81usc2jhx8fm&dl=0). We began using this script in April 2024, so updates will be ongoing (approximately monthly).

## Configuration
`update-from-remote.sh` has one required option (`-u`) which expects a remote file URL. An optional argument (`-a`) allows you to specify a local archive directory. (By default, this is set to `'./archive/'`). To use `push-to-dropbox.sh`, you'll have to create a `.env` file, which includes the following:

```bash
dbox_refresh_token=""
dbox_app_key=""
dbox_app_secret=""
dbox_out_path=""
```

You must first [create a Dropbox application](https://www.dropbox.com/developers/apps/create?_tk=pilot_lp&_ad=ctabtn1&_camp=create). Because this script is built to run on a server without intervention, you'll also need to set up a Dropbox refresh token, which is necessary because the API has moved to an `OAuth 2.0` authentication system for its API. See the [Dropbox OAuth documentation here](https://developers.dropbox.com/oauth-guide). Application key and secret are available through the Application dashboard.
