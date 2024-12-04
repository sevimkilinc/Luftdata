library(rvest)
library(httr)
library(dplyr)
library(stringr)
library(RMariaDB)
library(DBI)
library(lubridate)
library(logr)

log_open("/tmp/kurt")
log_print("Hej")
log_close()

UserA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
cookie = 'CookieScriptConsent={"bannershown":1,"action":"accept","consenttime":1718103120,"categories":"[\"targeting\",\"functionality\",\"performance\"]","key":"b35a847f-3299-443d-aad2-19365c976b63"}'              

baseurl = "https://envs2.au.dk/Luftdata/Presentation/table/Copenhagen/HCAB"

rawres <- GET(
  url = baseurl,
  add_headers(
    `User-Agent` = UserA,
    `Accept-Language` = "en-US,en;q=0.9",
    `Accept-Encoding` = "gzip, deflate, br",
    `Connection` = "keep-alive",
    `Accept` = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    `Cookie` = cookie
  )
)

print(rawres$status_code)
rawcontent <- httr::content(rawres, as = "text", encoding = "UTF-8")
page <- read_html(rawcontent)

token <- read_html(rawcontent) %>%
  html_element("input[name='__RequestVerificationToken']") %>% 
  html_attr("value")

# København - H. C. Andersens Boulevard
# Javascript for at få html af MainURL
main_url_KØBENHAVN_HCAB <- "https://envs2.au.dk/Luftdata/Presentation/table/MainTable/Copenhagen/HCAB"

mainKØBENHAVN_HCAB <- POST(
  url = main_url_KØBENHAVN_HCAB,
  add_headers(
    `User-Agent` = UserA
    #`Cookie` = cookie
  ),
  body = list(`__RequestVerificationToken` = token),
  encode = "form"
)

# Konverter POST response til dataframe
KØBENHAVN_HCAB_html <- content(mainKØBENHAVN_HCAB, as = "text", encoding = "UTF-8")

KØBENHAVN <- read_html(KØBENHAVN_HCAB_html) %>%
  html_element(".col-lg-12 table") %>%
  html_table()

mainKØBENHAVN_HCAB$status_code

colnames(KØBENHAVN)[colnames(KØBENHAVN) == "Målt (starttid)"] <- "måltstarttid"
KØBENHAVN$`måltstarttid` <- dmy_hm(KØBENHAVN$`måltstarttid`)

######################################################################################
# Anholt
main_url_ANHOLT <- "https://envs2.au.dk/Luftdata/Presentation/table/MainTable/Rural/ANHO"

mainANHOLT <- POST(
  url = main_url_ANHOLT,
  add_headers(
    `User-Agent` = UserA
    #`Cookie` = cookie
  ),
  body = list(`__RequestVerificationToken` = token),
  encode = "form"
)

# Konverter POST response til dataframe
ANHOLT_html <- content(mainANHOLT, as = "text", encoding = "UTF-8")

ANHOLT <- read_html(ANHOLT_html) %>%
  html_element(".col-lg-12 table") %>%
  html_table()

colnames(ANHOLT)[colnames(ANHOLT) == "Målt (starttid)"] <- "måltstarttid"
ANHOLT$`måltstarttid` <- dmy_hm(ANHOLT$`måltstarttid`)

#######################################################################################
# Risø
main_url_RISØ <- "https://envs2.au.dk/Luftdata/Presentation/table/MainTable/Rural/RISOE"

mainRISØ <- POST(
  url = main_url_RISØ,
  add_headers(
    `User-Agent` = UserA
    #`Cookie` = cookie
  ),
  body = list(`__RequestVerificationToken` = token),
  encode = "form"
)

# Konverter POST response til dataframe
RISØ_html <- content(mainRISØ, as = "text", encoding = "UTF-8")

RISØ <- read_html(RISØ_html) %>%
  html_element(".col-lg-12 table") %>%
  html_table()

colnames(RISØ)[colnames(RISØ) == "Målt (starttid)"] <- "måltstarttid"
RISØ$`måltstarttid` <- dmy_hm(RISØ$`måltstarttid`)

#######################################################################################
# Århus
main_url_ÅRHUS <- "https://envs2.au.dk/Luftdata/Presentation/table/MainTable/Aarhus/AARH3"

mainÅRHUS <- POST(
  url = main_url_ÅRHUS,
  add_headers(
    `User-Agent` = UserA
    #`Cookie` = cookie
  ),
  body = list(`__RequestVerificationToken` = token),
  encode = "form"
)

# Konverter POST response til dataframe
ÅRHUS_html <- content(mainÅRHUS, as = "text", encoding = "UTF-8")

AARHUS <- read_html(ÅRHUS_html) %>%
  html_element(".col-lg-12 table") %>%
  html_table()

colnames(AARHUS)[colnames(AARHUS) == "Målt (starttid)"] <- "måltstarttid"
AARHUS$`måltstarttid` <- dmy_hm(AARHUS$`måltstarttid`)

# Opret forbindelse til databasen
connection <- dbConnect(RMariaDB::MariaDB(),
                        dbname = "LUFTDATA2",      
                        user = "root",
                        password = "18Chelsea0092!",  
                        host = "localhost",
                        port = 3306
)


#dbWriteTable(connection, name = "KØBENHAVN", value = KØBENHAVN, append = TRUE, row.names = FALSE)
#dbWriteTable(connection, name = "ANHOLT", value = ANHOLT, append = TRUE, row.names = FALSE)
#dbWriteTable(connection, name = "RISØ", value = RISØ, append = TRUE, row.names = FALSE)
#dbWriteTable(connection, name = "AARHUS", value = AARHUS, append = TRUE, row.names = FALSE)


# Hent gamle data fra databasen
KØBENHAVN_OLD <- dbReadTable(connection, "KØBENHAVN")
ANHOLT_OLD <- dbReadTable(connection, "ANHOLT")
RISØ_OLD <- dbReadTable(connection, "RISØ")
AARHUS_OLD <- dbReadTable(connection, "AARHUS")

# Find de nye data, som ikke allerede findes i databasen
KØBENHAVN_NEW <- KØBENHAVN %>% filter(måltstarttid > max(KØBENHAVN_OLD$måltstarttid, na.rm = TRUE))
ANHOLT_NEW <- ANHOLT %>% filter(måltstarttid > max(ANHOLT_OLD$måltstarttid, na.rm = TRUE))
RISØ_NEW <- RISØ %>% filter(måltstarttid > max(RISØ_OLD$måltstarttid, na.rm = TRUE))
AARHUS_NEW <- AARHUS %>% filter(måltstarttid > max(AARHUS_OLD$måltstarttid, na.rm = TRUE))

# Tilføj de nye data til databasen
if (nrow(KØBENHAVN_NEW) > 0) {
  dbWriteTable(connection, name = "KØBENHAVN", value = KØBENHAVN_NEW, append = TRUE, row.names = FALSE)
}

if (nrow(ANHOLT_NEW) > 0) {
  dbWriteTable(connection, name = "ANHOLT", value = ANHOLT_NEW, append = TRUE, row.names = FALSE)
}

if (nrow(RISØ_NEW) > 0) {
  dbWriteTable(connection, name = "RISØ", value = RISØ_NEW, append = TRUE, row.names = FALSE)
}

if (nrow(AARHUS_NEW) > 0) {
  dbWriteTable(connection, name = "AARHUS", value = AARHUS_NEW, append = TRUE, row.names = FALSE)
}

# Luk forbindelsen til databasen
dbDisconnect(connection)




