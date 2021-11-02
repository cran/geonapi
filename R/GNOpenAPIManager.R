#' @name GNOpenAPIManager
#' @title GNOpenAPIManager
#' @aliases GNOpenAPIManager
#'
#' @docType class
#' 
#' @export
#' @keywords geonetwork rest api
#' @return Object of \code{\link{R6Class}} with methods for communication with
#' the REST API of a GeoNetwork instance using the legacy API.
#' @format \code{\link{R6Class}} object.
#' 
#' @examples
#' \dontrun{
#'    GNOpenAPIManager$new("http://localhost:8080/geonetwork", "admin", "geonetwork", "4.0.5")
#' }
#'
#'@section Abstract Methods:
#' \describe{
#'  \item{\code{new(url, user, pwd, version, logger, keyring_backend)}}{
#'    This method is used to instantiate a \code{GNOpenAPIManager} with the \code{url} of the
#'    GeoNetwork and credentials to authenticate (\code{user}/\code{pwd}).
#'    
#'    The \code{keyring_backend} can be set to use a different backend for storing 
#'    the Geonetwork password/token with \pkg{keyring} (Default value is 'env').
#'    
#'    The logger can be either NULL, "INFO" (with minimum logs), or "DEBUG" 
#'    (for complete curl http calls logs)
#'  }
#'  \item{\code{logger(type, text)}}{
#'    Basic logger to report geonapi logs. Used internally
#'  }
#'  \item{\code{INFO(text)}}{
#'    Logger to report information. Used internally
#'  }
#'  \item{\code{WARN(text)}}{
#'    Logger to report warnings. Used internally
#'  }
#'  \item{\code{ERROR(text)}}{
#'    Logger to report errors. Used internally
#'  }
#'  \item{\code{getUrl()}}{
#'    Get the authentication URL
#'  }
#'  \item{\code{getLang()}}{
#'    Get the service lang
#'  }
#'}
#'
#' @section Methods:
#' \describe{
#'  \item{\code{new(url, user, pwd, version, logger, keyring_backend)}}{
#'    This method is used to instantiate a \code{GNOpenAPIManager} with the \code{url} of the
#'    GeoNetwork and credentials to authenticate (\code{user}/\code{pwd}).
#'    
#'    The \code{keyring_backend} can be set to use a different backend for storing 
#'    the Geonetwork password/token with \pkg{keyring} (Default value is 'env').
#'    
#'    The logger can be either NULL, "INFO" (with minimum logs), or "DEBUG" 
#'    (for complete curl http calls logs)
#'    
#'  }
#'  \item{\code{login(user, pwd)}}{
#'    This methods attempts a connection to GeoNetwork REST API. User internally
#'    during initialization of \code{GNLegacyAPIManager}.
#'  }
#'  \item{\code{getGroups()}}{
#'    Retrieves the list of user groups available in Geonetwork
#'  }
#'  \item{\code{getTags()}}{
#'    Retrieves the list of tags (categories) available in Geonetwork
#'  }
#'  \item{\code{getCategories()}}{
#'    Same as \code{getTags()}
#'  }
#'  \item{\code{getMetadataByUUID(uuid)}}{
#'    Get a metadata by UUID. Returns an object of class \code{ISOMetadata} (ISO 19115)
#'    or \code{ISOFeatureCatalogue} (ISO 19110) (from \pkg{geometa} package)
#'  }
#'  \item{\code{insertRecord(xml, file, geometa, metadataType, uuidProcessing, 
#'                             group, category, rejectIfInvalid, publishToAll,
#'                             transformWith, schema, extra, 
#'                             geometa_validate, geometa_inspire)}}{
#'    Inserts a record by file, XML object or \pkg{geometa} object of class \code{ISOMetadata} or \code{ISOFeatureCatalogue}. 
#'    Extra parameters related to \pkg{geometa} objects: \code{geometa_validate} (TRUE by default) and \code{geometa_inspire} 
#'    (FALSE by default) can be used to perform ISO and INSPIRE validation respectively.
#'  }
#'  \item{\code{insertMetadata(xml, file, geometa, metadataType, uuidProcessing, 
#'                             group, category, rejectIfInvalid, publishToAll,
#'                             transformWith, schema, extra, 
#'                             geometa_validate, geometa_inspire)}}{
#'    Inserts a metadata by file, XML object or \pkg{geometa} object of class \code{ISOMetadata} or \code{ISOFeatureCatalogue}. 
#'    Extra parameters related to \pkg{geometa} objects: \code{geometa_validate} (TRUE by default) and \code{geometa_inspire} 
#'    (FALSE by default) can be used to perform ISO and INSPIRE validation respectively.
#'  }
#'  \item{\code{updateMetadata(xml, file, geometa, metadataType, 
#'                             group, category, rejectIfInvalid, publishToAll,
#'                             transformWith, schema, extra, 
#'                             geometa_validate, geometa_inspire)}}{
#'    Updates a metadata by file, XML object or \pkg{geometa} object of class
#'    'ISOMetadata' or 'ISOFeatureCatalogue'. Extra parameters \code{geometa_validate} (TRUE 
#'    by default) and \code{geometa_inspire} (FALSE by default) can be used with geometa objects 
#'    for perform ISO and INSPIRE validation respectively.
#'  }
#'  \item{\code{deleteMetadata(id, withBackup)}}{
#'    Deletes a metadata
#'  }
#' }
#' 
#' @author Emmanuel Blondel <emmanuel.blondel1@@gmail.com>
GNOpenAPIManager <- R6Class("GNOpenAPIManager",
  inherit = GNAbstractManager,
  private = list(),
  
  public = list(
    #manager
    initialize = function(url, user = NULL, pwd = NULL, version, logger = NULL,
                          keyring_backend = 'env'){
      super$initialize(url, user = user, pwd = pwd, version = version, logger = logger,
                       keyring_backend = keyring_backend)
      self$basicAuth <- TRUE
      
      #baseUrl
      self$url = sprintf("%s/srv", url)
      private$keyring_service <- paste0("geonapi@", url)
      
      #try to login
      if(!is.null(user) && !is.null(pwd)){        
        self$INFO(sprintf("Connecting to GeoNetwork services as authenticated user '%s'", user))
        self$login(user, pwd)
      }else{
        self$INFO("Connected to GeoNetwork services as anonymous user")
      }
    },
    
    #login
    #---------------------------------------------------------------------------
    login = function(user, pwd){
      
      req <- GNUtils$POST(
        url = self$getUrl(), path = "/info?type=me",
        user = user, pwd = pwd, content = NULL, contentType = NULL,
        verbose = TRUE 
      )
      
      private$user <- user
      private$keyring_backend$set_with_value(private$keyring_service, username = paste0(user,"_pwd"), password = pwd)
      
      req_cookies <- cookies(req)
      cookies <- as.list(req_cookies$value)
      names(cookies) <- req_cookies$name
      if(length(cookies[names(cookies)=="XSRF-TOKEN"])>0){
        token <- cookies[names(cookies)=="XSRF-TOKEN"][[1]]
        private$keyring_backend$set_with_value(private$keyring_service, username = paste0(user,"_token"), password = token)
      }
      cookies <- unlist(cookies[names(cookies)!="XSRF-TOKEN"])
      private$cookies <- paste0(sapply(names(cookies), function(cookiename){paste0(cookiename,"=",cookies[[cookiename]])}),collapse=";")
      
      keyring_token <- private$getToken()
      if(!is.null(keyring_token)){
        req <- GNUtils$POST(
          url = self$getUrl(), path = "/info?type=me",
          user = user, pwd = private$getPwd(), token = keyring_token, cookies = private$cookies, content = NULL, contentType = NULL,
          verbose = TRUE 
        )
      }
      
      if(status_code(req) == 401){
        err <- "Impossible to login to GeoNetwork: Wrong credentials"
        self$ERROR(err)
        stop(err)
      }
      if(status_code(req) == 404){
        err <- "Impossible to login to GeoNetwork: Incorrect URL or GeoNetwork temporarily unavailable"
        self$ERROR(err)
        stop(err)
      }
      if(status_code(req) != 200){
        err <- "Impossible to login to GeoNetwork: Unexpected error"
        self$ERROR(err)
        stop(err)
      }
      
      if(status_code(req) == 200){
        self$INFO("Successfully authenticated to GeoNetwork!\n")
      }
      return(TRUE)
    },
    
    
    #getGroups
    #---------------------------------------------------------------------------
    getGroups = function(){
      out <- NULL
      self$INFO("Getting user groups...")
      req <- GNUtils$GET(
        url = self$getUrl(),
        path = "/api/groups",
        token = private$getToken(), cookies = private$cookies,
        user = private$user, 
        pwd = private$getPwd(),
        verbose = self$verbose.debug
      )
      if(status_code(req) == 200){
        self$INFO("Successfully fetched user groups!")
        json <- content(req)
        out <- do.call("rbind", lapply(json, function(group){
          out.group <- data.frame(
            id = group$id,
            name = group$name,
            stringsAsFactors = FALSE
          )
          return(out.group)
        }))
      }else{
        self$ERROR("Error while fetching user groups")
      }
      return(out)
    },
    
    #getTags
    #---------------------------------------------------------------------------
    getTags = function(){
      out <- NULL
      self$INFO("Getting tags (categories)...")
      req <- GNUtils$GET(
        url = self$getUrl(),
        path = "/api/tags",
        token = private$getToken(), cookies = private$cookies,
        user = private$user, 
        pwd = private$getPwd(),
        verbose = self$verbose.debug
      )
      if(status_code(req) == 200){
        self$INFO("Successfully fetched tags (categories)!")
        json <- content(req, encoding = "UTF-8")
        out <- do.call("rbind", lapply(json, function(json.tag){
          out.tag <- data.frame(
            id = json.tag$id,
            name = json.tag$name,
            stringsAsFactors = FALSE
          )
          labels <- data.frame(json.tag$label)
          colnames(labels) <- paste0("label_", colnames(labels))
          out.tag <- cbind(out.tag, labels)
          return(out.tag)
        }))
      }else{
        self$ERROR("Error while fetching tags (categories)")
      }
      return(out)
    },
    
    #getCategories
    #---------------------------------------------------------------------------
    getCategories = function(){
      return(self$getTags())
    },
    
    #getMetadataByUUID
    #---------------------------------------------------------------------------
    getMetadataByUUID = function(uuid, 
                                 addSchemaLocation = TRUE, increasePopularity = TRUE, approved = TRUE){
      addSchemaLocation <- tolower(as.character(addSchemaLocation))
      increasePopularity <- tolower(as.character(increasePopularity))
      approved <- tolower(as.character(approved))
    
      self$INFO(sprintf("Fetching metadata for uuid = '%s'", uuid))
      out <- NULL
      req <- GNUtils$GET(
        url = self$getUrl(),
        path = sprintf("/api/records/%s/formatters/xml?addSchemaLocation=%s&increasePopularity=%s&approved=%s", 
                       uuid, addSchemaLocation, increasePopularity, approved),
        token = private$getToken(), cookies = private$cookies,
        user = private$user,
        pwd = private$getPwd(),
        accept = "application/xml", contentType = "application/xml",
        verbose = self$verbose.debug
      )
      if(status_code(req) == 200){
        self$INFO("Successfully fetched metadata!")
        xml <- GNUtils$parseResponseXML(req, "UTF-8")
        
        #bridge to geometa package once geometa XML decoding supported
        isoClass <- xmlName(xmlRoot(xml))
        out <- NULL
        if(isoClass=="MD_Metadata"){
          out <- geometa::ISOMetadata$new(xml = xml)
        }else if(isoClass=="FC_FeatureCatalogue"){
          out <- geometa::ISOFeatureCatalogue$new(xml = xml)
        }
      }else{
        self$ERROR(sprintf("Error while fetching metadata - %s", message_for_status(status_code(req))))
        self$ERROR(content(req))
      }
      return(out)
    },
    
    
    #insertRecord
    #---------------------------------------------------------------------------
    insertRecord = function(xml = NULL, file = NULL, geometa = NULL,
                            metadataType = "METADATA", uuidProcessing = "NOTHING", 
                            group, category = NULL, rejectIfInvalid = FALSE, publishToAll = TRUE,
                            transformWith = "_none_", schema = NULL, extra = NULL,
                            geometa_validate = TRUE, geometa_inspire = FALSE){
      
      allowedMetadataTypes <- c("METADATA", "TEMPLATE", "SUB_TEMPLATE", "TEMPLATE_OF_SUB_TEMPLATE")
      if(!metadataType %in% allowedMetadataTypes){
        errMsg <- sprintf("Invalid metadataType value '%s'. Value should be among values [%s]", metadataType,
                          paste0(allowedMetadataTypes, collapse=","))
        self$ERROR(errMsg)
        stop(errMsg)
      }
      
      allowedUuidProcessing <- c("GENERATEUUID", "NOTHING", "OVERWRITE")
      if(!uuidProcessing %in% allowedUuidProcessing){
        errMsg <- sprintf("Invalid uuidProcessing value '%S'. Value should be among values [%s]", uuidProcessing,
                          paste0(allowedUuidProcessing, collapse=","))
      }
      
      if(is.null(category)) category <- "_none_"
      
      self$INFO("Uploading metadata ...")
      out <- NULL
      data <- NULL
      isTempFile <- FALSE
      if(!is.null(xml)){
        tempf = tempfile(tmpdir = tempdir())
        file <- paste(tempf,".xml",sep='')
        isTempFile <- TRUE
        saveXML(xml, file, encoding = "UTF-8")
      }
      if(!is.null(geometa)){
        if(!is(geometa, "ISOMetadata") & !is(geometa, "ISOFeatureCatalogue")){
          stop("Object 'geometa' should be of class 'ISOMetadata' or 'ISOFeatureCatalogue")
        }
        tempf = tempfile(tmpdir = tempdir())
        file <- paste(tempf,".xml",sep='')
        isTempFile <- TRUE
        geometa$save(file = file, validate = geometa_validate, inspire = geometa_inspire)
      }
      
      if(is.null(file)){
        stop("At least one of 'file', 'xml', or 'geometa' argument is required!")
      }
      
      #request payload
      reqParams <- list(
        metadataType = metadataType,
        uuidProcessing = uuidProcessing,
        group = group,
        category = category,
        rejectIfInvalid = tolower(as.character(rejectIfInvalid)),
        publishToAll = tolower(as.character(publishToAll)),
        transformWith = transformWith,
        schema = schema,
        extra = extra
      )
      reqParams <- reqParams[!sapply(reqParams, is.null)]
      path = sprintf("/api/records?%s", paste0(sapply(names(reqParams), function(x){paste0(x,"=",reqParams[[x]])}), collapse="&")) 
      
      req <- GNUtils$POST(
        url = self$getUrl(),
        path = path,
        token = private$getToken(), cookies = private$cookies,
        user = private$user, 
        pwd = private$getPwd(),
        content = list(
          file = httr::upload_file(file)
        ),
        contentType = "multipart/form-data",
        encode = "multipart",
        verbose = self$verbose.debug
      )
      if(status_code(req) == 201){
        self$INFO("Successfully uploaded metadata!")
        response <- content(req)
        out <- response
      }else{
        self$ERROR(sprintf("Error while uploading metadata - %s", message_for_status(status_code(req))))
        self$ERROR(content(req))
      }
      if(isTempFile) unlink(file)
      return(out)
    },
    
    #insertMetadata
    #---------------------------------------------------------------------------
    insertMetadata = function(xml = NULL, file = NULL, geometa = NULL,
                              metadataType = "METADATA", uuidProcessing = "NOTHING", 
                              group, category = NULL, rejectIfInvalid = FALSE, publishToAll = TRUE,
                              transformWith = "_none_", schema = NULL, extra = NULL,
                              geometa_validate = TRUE, geometa_inspire = FALSE){
      self$INFO("Inserting metadata ...")
      inserted <- self$insertRecord(xml = xml, file = file, geometa = geometa,
                        metadataType = metadataType, uuidProcessing = uuidProcessing, 
                        group = group, category = category, rejectIfInvalid = rejectIfInvalid, publishToAll = publishToAll,
                        transformWith = transformWith, schema = schema, extra = extra,
                        geometa_validate = geometa_validate, geometa_inspire = geometa_inspire)
    },
    
    #updateMetadata
    #---------------------------------------------------------------------------
    updateMetadata = function(xml = NULL, file = NULL, geometa = NULL,
                              metadataType = "METADATA",
                              group, category = NULL, rejectIfInvalid = FALSE, publishToAll = TRUE,
                              transformWith = "_none_", schema = NULL, extra = NULL,
                              geometa_validate = TRUE, geometa_inspire = FALSE){
      self$INFO("Updating metadata ...")
      self$insertRecord(xml = xml, file = file, geometa = geometa,
                          metadataType = metadataType, uuidProcessing = "OVERWRITE", 
                          group = group, category = category, rejectIfInvalid = rejectIfInvalid, publishToAll = publishToAll,
                          transformWith = transformWith, schema = schema, extra = extra,
                          geometa_validate = geometa_validate, geometa_inspire = geometa_inspire)
    },
    
    #deleteMetadata
    #---------------------------------------------------------------------------
    deleteMetadata = function(id, withBackup = TRUE){
      self$INFO(sprintf("Deleting metadata id = %s ...", id))
      out <- NULL
      req <- GNUtils$DELETE(
        url = self$getUrl(),
        path = sprintf("/api/records?uuids=%s&withBackup=%s", id, tolower(as.character(withBackup))),
        token = private$getToken(), cookies = private$cookies,
        user = private$user,
        pwd = private$getPwd(),
        verbose = self$verbose.debug
      )
      if(status_code(req) == 200){
        self$INFO("Successfully deleted metadata!")
        response = content(req)
        out <- response
      }else{
        self$ERROR(sprintf("Error while deleting metadata - %s", message_for_status(status_code(req))))
        self$ERROR(content(req))
      }
      return(out)
    }

  )
                              
)