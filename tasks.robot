*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Playwright
Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.PDF
Library             RPA.FileSystem
Library             RPA.Archive
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault


*** Tasks ***
# https://robotsparebinindustries.com/orders.csv

Order robots from RobotSpareBin Industries Inc
    ${secret}=    Get Secret    robotSpareBin
    ${csv_url}=    Ask for the CSV
    Open the robot order website    ${secret}[url]
    ${orders}=    Get orders    ${csv_url}
    FOR    ${row}    IN    @{orders}
        # Process each row independently
        TRY
            Log    Processing row: ${row}
            Close the annoying modal
            Fill the form    ${row}
            Preview the robot
            Wait Until Keyword Succeeds    5x    1 sec    Submit the order
            ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
            ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
            Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
            Go to order another robot
        EXCEPT    AS    ${error_message}
            Log    Exception occured: ${error_message}    ERROR
            Go to initial page of the website
        END
    END
    Create a ZIP file of the receipts


*** Keywords ***
Open the robot order website
    [Arguments]    ${url}
    New Browser    browser=firefox    headless=False
    New Page    ${url}

Get orders
    [Arguments]    ${csv_url}
    ${orders_file_path}=    Set Variable    ${OUTPUT_DIR}${/}orders.csv
    RPA.HTTP.Download
    # ...    https://robotsparebinindustries.com/orders.csv
    ...    ${csv_url}
    ...    target_file=${orders_file_path}
    ...    overwrite=True
    ${table}=    Read table from CSV    ${orders_file_path}    header=True
    RETURN    ${table}

Close the annoying modal
    Click element if it appears    xpath=//button[text()='OK']

Click element if it appears
    [Arguments]    ${locator}
    ${default_failure_keyword}=    Register Keyword To Run On Failure    ${None}
    Run Keyword And Ignore Error    Click    ${locator}
    Register Keyword To Run On Failure    ${default_failure_keyword}

Fill the form
    [Arguments]    ${row}
    Select Options By    css=select#head    value    ${row}[Head]
    Click    css=input#id-body-${row}[Body]
    Fill Text    css=input[placeholder='Enter the part number for the legs']    ${row}[Legs]
    Fill Text    css=#address    ${row}[Address]

Preview the robot
    Click    css=#preview

Submit the order
    Click    css=#order
    Get Element    css=#receipt    # Assert that the order was submitted

Store the receipt as a PDF file
    [Arguments]    ${order_number}
    ${html_receipt}=    Get Property    css=#receipt    innerHTML
    ${pdf}=    Set Variable    ${OUTPUT_DIR}${/}receipts${/}Receipt ${order_number}.pdf
    Html To Pdf    ${html_receipt}    ${pdf}
    RETURN    ${pdf}

Take a screenshot of the robot
    [Arguments]    ${order_number}
    ${screenshot}=    Set Variable    ${OUTPUT_DIR}${/}previews${/}robot-preview-${order_number}.png
    Take Screenshot    selector=css=#robot-preview-image    filename=${screenshot}
    RETURN    ${screenshot}

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    ${files}=    Create List
    ...    ${screenshot}:align=center
    # ...    ${pdf}
    Add Files To Pdf    ${files}    target_document=${pdf}    append=True

Go to order another robot
    Click    css=#order-another

Create a ZIP file of the receipts
    Archive Folder With Zip    ${OUTPUT_DIR}${/}receipts    ${OUTPUT_DIR}${/}receipts.zip

Go to initial page of the website
    Reload

Ask for the CSV
    Add heading    Enter the URL for the orders
    Add text input    url
    ${result}=    Run dialog
    RETURN    ${result}[url]
