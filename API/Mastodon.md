FORMAT: 1A


# Instances [/api/v1/instance]

## GetInstance [GET]

+ Response 200
    + Attributes (Instance)


# Accounts [/api/v1/accounts]

## GetCurrentUser [GET /api/v1/accounts/verify_credentials]

+ Response 200
    + Attributes (Account)


# Apps [/api/v1/apps{?client_name,redirect_uris,scopes,website}]

## RegisterApp [POST]

+ Parameters
    + client_name (string, required) - Name of your application
    + redirect_uris (string, required) - Where the user should be redirected after authorization (for no redirect, use `urn:ietf:wg:oauth:2.0:oob`)
    + scopes (string, required) - This can be a space-separated list of the following items: "read", "write" and "follow" (see [this page](OAuth-details.md) for details on what the scopes do)
    + website (string, optional) - URL to the homepage of your app

+ Response 200
    + Attributes (ClientApplication)

# Login [/oauth/token]

## LoginSilent [POST]

+ Request (application/json)
    + Attributes (object)
        + client_id (string, required)
        + client_secret (string, required)
        + scope (string, required)
        + grant_type (string, required)
        + username (string, required)
        + password (string, required)

+ Response 200
    + Attributes (LoginSettings)

# Timelines [/api/v1/timelines]

+ Attributes (array[Status])

## GetHomeTimeline [GET /api/v1/timelines/home{?max_id,since_id,limit}]

+ Parameters
    + max_id (number, optional) - Get a list of timelines with ID less than this value
    + since_id (number, optional) - Get a list of timelines with ID greater than this value
    + limit (number, optional) - Maximum number of statuses on the requested timeline to get (Default 20, Max 40)

+ Response 200
    + Attributes (Timelines)

## GetPublicTimeline [GET /api/v1/timelines/public{?local,max_id,since_id,limit}]

+ Parameters
    + local (string, optional) - Only return statuses originating from this instance (public and tag timelines only)
    + max_id (number, optional) - Get a list of timelines with ID less than this value
    + since_id (number, optional) - Get a list of timelines with ID greater than this value
    + limit (number, optional) - Maximum number of statuses on the requested timeline to get (Default 20, Max 40)

+ Response 200
    + Attributes (Timelines)

# Reblogging [/api/v1/statuses/{id}/reblog]

## Boost [POST]

+ Parameters
    + id (number, required)

+ Response 200
    + Attributes (Status)

# Favouriting [/api/v1/statuses/{id}/favourite]

## Favorite [POST]

+ Parameters
    + id (number, required)

+ Response 200
    + Attributes (Status)

# Posting a new statuses [/api/v1/statuses{?status,in_reply_to_id,media_ids,sensitive,spoiler_text,visibility}]

## PostStatus [POST]

+ Parameters
    + status (string, required) - The text of the status
    + in_reply_to_id (string, optional) - local ID of the status you want to reply to
    + media_ids (string, optional) - Array of media IDs to attach to the status (maximum 4)
    + sensitive (boolean, optional) - Set this to mark the media of the status as NSFW
    + spoiler_text (string, optional) - Text to be shown as a warning before the actual content
    + visibility (string, optional) - Either "direct", "private", "unlisted" or "public"

+ Response 200
    + Attributes (Status)

# Data Structures

## Instance
+ uri (string, required) - URI of the current instance
+ title (string , required) - The instance's title
+ description (string , required) - A description for the instance
+ email (string , required) - An email address which can be used to contact the instance administrator
+ version (string, optional) - The Mastodon version used by instance

## Account

+ id (number, required) - The ID of the account
+ username (string, required) - The username of the account
+ acct (string, required) - Equals `username` for local users, includes `@domain` for remote ones
+ display_name (string, required) - The account's display name
+ locked (boolean, required) - Boolean for when the account cannot be followed without waiting for approval first
+ created_at (string, required) - The time the account was created
+ followers_count (number, required) - The number of followers for the account
+ following_count (number, required) - The number of accounts the given account is following
+ statuses_count (number, required) - The number of statuses the account has made
+ note (string, required) - Biography of user
+ url (string, required) - URL of the user's profile page (can be remote)
+ avatar (string, required) - URL to the avatar image
+ avatar_static (string, required) - URL to the avatar static image (gif)
+ header (string, required) - URL to the header image
+ header_static (string, required) - URL to the header static image (gif)

## Status

+ id (number, required) - The ID of the status
+ uri (string, required) - A Fediverse-unique resource ID
+ url (string, required) - URL to the status page (can be remote)
+ account (Account, required) - The [Account](#account) which posted the status
+ in_reply_to_id (number, optional) - `null` or the ID of the status it replies to
+ in_reply_to_account_id (number, optional) - `null` or the ID of the account it replies to
  // reblog (Status, optional) - `null` or the reblogged [Status](#status)
+ content (string, required) - Body of the status; this will contain HTML (remote HTML already sanitized)
+ created_at (string, required) - The time the status was created
+ reblogs_count (number, required) - The number of reblogs for the status
+ favourites_count (number, required) - The number of favourites for the status
+ reblogged (boolean, optional) - Whether the authenticated user has reblogged the status
+ favourited (boolean, optional) - Whether the authenticated user has favourited the status
+ sensitive (boolean, optional) - Whether media attachments should be hidden by default
+ spoiler_text (string, required) - If not empty, warning text that should be displayed before the actual content
+ visibility (string, required) - One of: `public`, `unlisted`, `private`, `direct`
+ media_attachments (array[Attachment], fixed-type, required) - An array of [Attachments](#attachment)
+ mentions (array[Mention], fixed-type, required) - An array of [Mentions](#mention)
+ tags (array[Tag], fixed-type, required) - An array of [Tags](#tag)
+ application (Application, optional) - [Application](#application) from which the status was posted
+ language (string, optional) - The detected language for the status (default: en)

## Application

+ name (string, required) - Name of the app
+ website (string, optional) - Homepage URL of the app

## Tag

+ name (string, required) - The hashtag, not including the preceding `#`
+ url (string, required) - The URL of the hashtag

### Mention

+ url (string, required) - URL of user's profile (can be remote)
+ username (string, required) - The username of the account
+ acct (string, required)-  Equals `username` for local users, includes `@domain` for remote ones
+ id (number, required) - Account ID

### Attachment

+ id (number, required) - ID of the attachment
+ type (string, required) - One of: "image", "video", "gifv"
+ url (string, required) - URL of the locally hosted version of the image
+ remote_url (string, optional) - For remote images, the remote URL of the original image
+ preview_url (string, required) - URL of the preview image
+ text_url (string, optional) - Shorter URL for the image, for insertion into text (only present on local images)

### Notification

+ id (number, required) - The notification ID
+ type (string, required) - One of: "mention", "reblog", "favourite", "follow"
+ created_at (string, required) - The time the notification was created
+ account (Account, required) - The [Account](#account) sending the notification to the user
+ status (Status, optional) - The [Status](#status) associated with the notification, if applicable

### ClientApplication
+ id (number, required)
+ redirect_uri (string, required)
+ client_id (string, required)
+ client_secret (string, required)

### LoginSettings
+ access_token (string, required)
+ token_type (string, required)
+ scope (string, required)
+ created_at (number, required) - only here: UNIX timestamp
