package main

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"reflect"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type resumeFormat struct {
	Value struct {
		Document string `json:"ParsedDocument"`
	} `json:"Value"`
}

type affixFormat struct {
	Type string `json:"@type"`
	Text string `json:"#text"`
}

type deliveryAddressFormat struct {
	AddressLine []string `json:"AddressLine"`
}

type postalFormat struct {
	CountryCode     *string                `json:"CountryCode"`
	PostalCode      *string                `json:"PostalCode"`
	Municipality    *string                `json:"Municipality"`
	Region          []*string              `json:"Region"`
	DeliveryAddress *deliveryAddressFormat `json:"DeliveryAddress"`
}

type telephoneFormat struct {
	FormattedNumber *string `json:"FormattedNumber"`
}

type contactInfoFormat struct {
	Resume struct {
		Structured struct {
			ContactInfo struct {
				PersonName struct {
					FormattedName string        `json:"FormattedName"`
					GivenName     string        `json:"GivenName"`
					MiddleName    string        `json:"MiddleName"`
					FamilyName    string        `json:"FamilyName"`
					Affix         []affixFormat `json:"Affix"`
				} `json:"PersonName"`
				ContactMethod []struct {
					PostalAddress        *postalFormat    `json:"PostalAddress"`
					Mobile               *telephoneFormat `json:"Mobile"`
					Telephone            *telephoneFormat `json:"Telephone"`
					InternetEmailAddress *string          `json:"InternetEmailAddress"`
					InternetWebAddress   *string          `json:"InternetWebAddress"`
				} `json:"ContactMethod"`
			} `json:"ContactInfo"`
		} `json:"StructuredXMLResume"`
	} `json:"Resume"`
}

type parsedContactFormat struct {
	FirstName         string `json:"first_name"`
	MiddleName        string `json:"middle_name"`
	LastName          string `json:"last_name"`
	AristocraticTitle string `json:"aristocratic_title"`
	FormOfAddress     string `json:"form_of_address"`
	Generation        string `json:"generation"`
	Qualification     string `json:"qualification"`
	AddressLine1      string `json:"address_line_1"`
	AddressLine2      string `json:"address_line_2"`
	// Address info
	City        *string `json:"city"`
	State       *string `json:"state"`
	PostalCode  *string `json:"postal_code"`
	Country     *string `json:"country"`
	HomePhone   *string `json:"home_phone"`
	MobilePhone *string `json:"mobile_phone"`
	Website     *string `json:"website"`
	Email       *string `json:"email"`
}

type employmentInfoFormat struct {
	Resume struct {
		Structured struct {
			EmploymentHistory struct {
				EmployerOrg []struct {
					EmployerOrgName *string `json:"EmployerOrgName"`
					OrgInfo         *struct {
						PositionLocation []struct {
							Municipality *string `json:"Municipality"`
							Region       *string `json:"Region"`
							CountryCode  *string `json:"CountryCode"`
						} `json:"PositionLocation"`
					} `json:"OrgInfo"`
					PositionHistory []struct {
						OrgName struct {
							OrganizationName *string `json:"OrganizationName"`
						} `json:"OrgName"`
						Description *string `json:"Description"`
						Title       *string `json:"Title"`
						StartDate   struct {
							YearMonth *string `json:"YearMonth"`
						} `json:"StartDate"`
						EndDate struct {
							YearMonth *string `json:"YearMonth"`
						} `json:"EndDate"`
						CurrentEmployer *string `json:"@currentEmployer"`
					} `json:"PositionHistory"`
				} `json:"EmployerOrg"`
			} `json:"EmploymentHistory"`
		} `json:"StructuredXMLResume"`
	} `json:"Resume"`
}

type parsedEmploymentFormat struct {
	Employer        *string `json:"employer"`
	Division        *string `json:"division"`
	City            *string `json:"city"`
	State           *string `json:"state"`
	Country         *string `json:"country"`
	Title           *string `json:"title"`
	Description     *string `json:"description"`
	StartDate       *string `json:"start_date"`
	EndDate         *string `json:"end_date"`
	CurrentEmployer *string `json:"current_employer"`
}

type educationInfoFormat struct {
	Resume struct {
		Structured struct {
			EducationHistory struct {
				SchoolOrInstitution []struct {
					School []struct {
						SchoolName *string `json:"SchoolName"`
					} `json:"School"`
					PostalAddress *struct {
						Municipality *string  `json:"Municipality"`
						Region       []string `json:"Region"`
						CountryCode  *string  `json:"CountryCode"`
					} `json:"PostalAddress"`
					Degree []struct {
						DegreeType  *string `json:"@degreeType"`
						DegreeName  *string `json:"DegreeName"`
						DegreeMajor []*struct {
							Name []*string `json:"Name"`
						} `json:"DegreeMajor"`
						DegreeMinor []*struct {
							Name []*string `json:"Name"`
						} `json:"DegreeMinor"`
						DatesOfAttendance []*struct {
							StartDate *struct {
								Year      *string `json:"Year"`
								YearMonth *string `json:"YearMonth"`
							} `json:"StartDate"`
							EndDate *struct {
								Year      *string `json:"Year"`
								YearMonth *string `json:"YearMonth"`
							} `json:"EndDate"`
						} `json:"DatesOfAttendance"`
						DegreeDate *struct {
							Year      *string `json:"Year"`
							YearMonth *string `json:"YearMonth"`
						} `json:"DegreeDate"`
						DegreeMeasure *struct {
							EducationalMeasure *struct {
								MeasureValue *struct {
									StringValue *string `json:"StringValue"`
								} `json:"MeasureValue"`
								HighestPossibleValue *struct {
									StringValue *string `json:"StringValue"`
								} `json:"HighestPossibleValue"`
							} `json:"EducationalMeasure"`
						} `json:"DegreeMeasure"`
					} `json:"Degree"`
				} `json:"SchoolOrInstitution"`
			} `json:"EducationHistory"`
		} `json:"StructuredXMLResume"`
	} `json:"Resume"`
}

type parsedEducationFormat struct {
	SchoolName *string `json:"school_name"`

	City       *string `json:"city"`
	State      string  `json:"state"`
	Country    *string `json:"country"`
	DegreeType *string `json:"degree_type"`
	DegreeName *string `json:"degree_name"`
	Major      *string `json:"major"`
	Minor      *string `json:"minor"`
	StartDate  *string `json:"start_date"`
	EndDate    *string `json:"end_date"`
	GPA        *string `json:"gpa"`
	GPAOutOf   *string `json:"gpa_out_of"`
	Graduated  *string `json:"graduated"`
}

type parsedDataFormat struct {
	JSON struct {
		Contact    parsedContactFormat      `json:"contact"`
		Employment []parsedEmploymentFormat `json:"employment"`
		Education  []parsedEducationFormat  `json:"education"`
	} `json:"json"`
	Code int `json:"code"`
}

type payload struct {
	FileBytes string `json:"FileBytes"`
}

var (
	// ErrNon200Response non 200 status code in response
	ErrNon200Response = errors.New("Non 200 Response found")
)

var accountID = os.Getenv("SOVREN_ACCOUNT_ID")
var serviceKey = os.Getenv("SOVREN_SERVICE_KEY")

// Shape contact info to previously used ruby https://github.com/efleming/sovren/blob/master/lib/sovren/contact_information.rb
func parseContactInformation(resume resumeFormat) (parsedContactFormat, error) {
	var contactInfo contactInfoFormat
	var parsedContactData parsedContactFormat

	// Save Contact Info from Resume
	err := json.Unmarshal([]byte(resume.Value.Document), &contactInfo)
	if err != nil {
		fmt.Println("Error unmarshalling from resume document", err)
		return parsedContactData, nil
	}

	parsedContactData.FirstName = contactInfo.Resume.Structured.ContactInfo.PersonName.GivenName
	parsedContactData.MiddleName = contactInfo.Resume.Structured.ContactInfo.PersonName.MiddleName
	parsedContactData.LastName = contactInfo.Resume.Structured.ContactInfo.PersonName.FamilyName

	// Get Affix for titles and such
	for _, affix := range contactInfo.Resume.Structured.ContactInfo.PersonName.Affix {
		switch titleType := affix.Type; titleType {
		case "aristocraticTitle":
			parsedContactData.AristocraticTitle = affix.Text
		case "formOfAddress":
			parsedContactData.FormOfAddress = affix.Text
		case "generation":
			parsedContactData.Generation = affix.Text
		case "qualification":
			parsedContactData.Qualification = affix.Text
		}
	}

	// Get all the found contact methods
	for _, contactMethod := range contactInfo.Resume.Structured.ContactInfo.ContactMethod {
		if contactMethod.PostalAddress != nil {
			parsedContactData.City = contactMethod.PostalAddress.Municipality
			parsedContactData.State = contactMethod.PostalAddress.Region[0]
			parsedContactData.PostalCode = contactMethod.PostalAddress.PostalCode
			parsedContactData.Country = contactMethod.PostalAddress.CountryCode

			if contactMethod.PostalAddress.DeliveryAddress != nil {
				for index := range contactMethod.PostalAddress.DeliveryAddress.AddressLine {
					if index > 0 {
						parsedContactData.AddressLine2 = contactMethod.PostalAddress.DeliveryAddress.AddressLine[index]
					} else {
						parsedContactData.AddressLine1 = contactMethod.PostalAddress.DeliveryAddress.AddressLine[index]
					}
				}
			}
		}
		if contactMethod.Mobile != nil {
			parsedContactData.MobilePhone = contactMethod.Mobile.FormattedNumber
		}
		if contactMethod.Telephone != nil {
			parsedContactData.HomePhone = contactMethod.Telephone.FormattedNumber
		}
		if contactMethod.InternetWebAddress != nil {
			parsedContactData.Website = contactMethod.InternetWebAddress
		}
		if contactMethod.InternetEmailAddress != nil {
			parsedContactData.Email = contactMethod.InternetEmailAddress
		}
	}
	return parsedContactData, nil
}

// Shape contact info to previously used ruby https://github.com/efleming/sovren/blob/master/lib/sovren/employment.rb
func parseEmploymentHistory(resume resumeFormat) ([]parsedEmploymentFormat, error) {
	var employmentInfo employmentInfoFormat

	// Save Contact Info from Resume
	err := json.Unmarshal([]byte(resume.Value.Document), &employmentInfo)
	parsedEmploymentData := make([]parsedEmploymentFormat, len(employmentInfo.Resume.Structured.EmploymentHistory.EmployerOrg))
	if err != nil {
		fmt.Println("Error unmarshalling from resume document", err)
		return parsedEmploymentData, nil
	}

	for index, employer := range employmentInfo.Resume.Structured.EmploymentHistory.EmployerOrg {
		parsedEmploymentData[index].Employer = employer.EmployerOrgName
		if employer.EmployerOrgName == employer.PositionHistory[0].OrgName.OrganizationName {
			parsedEmploymentData[index].Division = nil
		}

		if employer.OrgInfo != nil {
			parsedEmploymentData[index].City = employer.OrgInfo.PositionLocation[0].Municipality
			parsedEmploymentData[index].State = employer.OrgInfo.PositionLocation[0].Region
			parsedEmploymentData[index].Country = employer.OrgInfo.PositionLocation[0].CountryCode
		}
		parsedEmploymentData[index].Title = employer.PositionHistory[0].Title
		parsedEmploymentData[index].Description = employer.PositionHistory[0].Description
		parsedEmploymentData[index].StartDate = employer.PositionHistory[0].StartDate.YearMonth
		parsedEmploymentData[index].EndDate = employer.PositionHistory[0].EndDate.YearMonth
		if employer.PositionHistory[0].CurrentEmployer != nil {
			var employerStatus = "true"
			parsedEmploymentData[index].CurrentEmployer = &employerStatus
		}
		jsonResponse, _ := json.MarshalIndent(parsedEmploymentData[index], "", "  ")
		fmt.Println(reflect.TypeOf(parsedEmploymentData))
		fmt.Println(string(jsonResponse))
	}

	return parsedEmploymentData, nil
}

// Shape contact info to previously used ruby https://github.com/efleming/sovren/blob/master/lib/sovren/education.rb
func parseEducationHistory(resume resumeFormat) ([]parsedEducationFormat, error) {
	var educationInfo educationInfoFormat

	// Save Contact Info from Resume
	err := json.Unmarshal([]byte(resume.Value.Document), &educationInfo)
	parsedEducationData := make([]parsedEducationFormat, len(educationInfo.Resume.Structured.EducationHistory.SchoolOrInstitution))
	if err != nil {
		fmt.Println("Error unmarshalling from resume document", err)
		return parsedEducationData, nil
	}

	for index, education := range educationInfo.Resume.Structured.EducationHistory.SchoolOrInstitution {
		parsedEducationData[index].SchoolName = education.School[0].SchoolName

		if education.PostalAddress != nil {
			parsedEducationData[index].City = education.PostalAddress.Municipality
			parsedEducationData[index].State = education.PostalAddress.Region[0]
			parsedEducationData[index].Country = education.PostalAddress.CountryCode
		}

		if education.Degree != nil {
			parsedEducationData[index].DegreeType = education.Degree[0].DegreeType
			parsedEducationData[index].DegreeName = education.Degree[0].DegreeName
			if education.Degree[0].DegreeMajor != nil {
				parsedEducationData[index].Major = education.Degree[0].DegreeMajor[0].Name[0]

			}
			if education.Degree[0].DegreeMinor != nil {
				parsedEducationData[index].Minor = education.Degree[0].DegreeMinor[0].Name[0]
			}
			if education.Degree[0].DegreeMeasure != nil {
				parsedEducationData[index].GPA = education.Degree[0].DegreeMeasure.EducationalMeasure.MeasureValue.StringValue
				parsedEducationData[index].GPAOutOf = education.Degree[0].DegreeMeasure.EducationalMeasure.HighestPossibleValue.StringValue
			}

			if education.Degree[0].DatesOfAttendance[0].StartDate.Year != nil {
				parsedEducationData[index].StartDate = education.Degree[0].DatesOfAttendance[0].StartDate.Year
			} else if education.Degree[0].DatesOfAttendance[0].StartDate.YearMonth != nil {
				parsedEducationData[index].StartDate = education.Degree[0].DatesOfAttendance[0].StartDate.YearMonth
			}

			if education.Degree[0].DatesOfAttendance[0].StartDate.Year != nil {
				parsedEducationData[index].EndDate = education.Degree[0].DatesOfAttendance[0].EndDate.Year
			} else if education.Degree[0].DatesOfAttendance[0].StartDate.YearMonth != nil {
				parsedEducationData[index].EndDate = education.Degree[0].DatesOfAttendance[0].EndDate.YearMonth
			}

			if education.Degree[0].DegreeDate.Year != nil {
				parsedEducationData[index].Graduated = education.Degree[0].DegreeDate.Year
			} else if education.Degree[0].DegreeDate.YearMonth != nil {
				parsedEducationData[index].Graduated = education.Degree[0].DegreeDate.YearMonth
			}
		}

		jsonResponse, _ := json.MarshalIndent(parsedEducationData[index], "", "  ")
		fmt.Println(reflect.TypeOf(parsedEducationData))
		fmt.Println(string(jsonResponse))
	}

	return parsedEducationData, nil
}

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	// TODO: Change to allow post data and download s3 file here

	// Open local file to send to Sovren as base64
	f, err := os.Open("ResumeSample.doc")
	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}

	// Create a new buffer base on file size
	fInfo, _ := f.Stat()
	var size int64 = fInfo.Size()
	buf := make([]byte, size)

	// read file content into buffer
	fReader := bufio.NewReader(f)
	fReader.Read(buf)
	encodedFile := base64.StdEncoding.EncodeToString(buf)
	defer f.Close()

	// Create data payload to send to Sovren
	payloadString := fmt.Sprintf(`{
			"DocumentAsBase64String": "%s",
			"RevisionDate": "%s"
	}`, encodedFile, string(time.Now().Format("2006-01-02")))

	// Convert to bytes
	payloadBytes := []byte(payloadString)

	// Create new http request with payload
	req, err := http.NewRequest(
		"POST",
		"https://rest.resumeparsing.com/v9/parser/resume",
		bytes.NewBuffer(payloadBytes),
	)

	// Set the request headers needed for Sovren api v9
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Sovren-AccountId", accountID)
	req.Header.Set("Sovren-ServiceKey", serviceKey)

	// Create the http client and fire away
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}
	defer resp.Body.Close()

	// If we have a good response from Sovren lets work on the data
	if resp.StatusCode == http.StatusOK {
		bodyBytes, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			fmt.Println(err)
		}

		var resume resumeFormat

		// Get full resume response from Sovren
		err = json.Unmarshal(bodyBytes, &resume)
		if nil != err {
			fmt.Println("Error unmarshalling from resume", err)
			return events.APIGatewayProxyResponse{
				Body:       fmt.Sprintf("Error, %v", string(err.Error())),
				StatusCode: 500,
			}, nil
		}

		// Combine into the response
		var parsedResponse parsedDataFormat
		parsedResponse.Code = 200
		parsedResponse.JSON.Contact, err = parseContactInformation(resume)
		parsedResponse.JSON.Employment, err = parseEmploymentHistory(resume)
		parsedResponse.JSON.Education, err = parseEducationHistory(resume)
		//fmt.Println(resume.Value.Document)
		if err != nil {
			fmt.Println("Error parsing contact information ", err)
			return events.APIGatewayProxyResponse{
				Body:       fmt.Sprintf("Error, %v", string(err.Error())),
				StatusCode: 500,
			}, nil
		}

		jsonResponse, err := json.MarshalIndent(parsedResponse, "", "  ")
		if err != nil {
			fmt.Println("Error unmarshalling from contactInfo", err)
			return events.APIGatewayProxyResponse{
				Body:       fmt.Sprintf("Error, %v", string(err.Error())),
				StatusCode: 500,
			}, nil
		}

		return events.APIGatewayProxyResponse{
			Body:       string(jsonResponse),
			Headers:    map[string]string{"Content-Type": "application/json"},
			StatusCode: 200,
		}, nil
	}

	if resp.StatusCode != 200 {
		return events.APIGatewayProxyResponse{}, ErrNon200Response
	}

	if nil != err {
		fmt.Println("Error unmarshalling from XML", err)
		return events.APIGatewayProxyResponse{
			Body:       fmt.Sprintf("Error, %v", string(err.Error())),
			StatusCode: 500,
		}, nil
	}

	result, err := json.Marshal(resp.Body)
	if nil != err {
		fmt.Println("Error marshalling to JSON", err)
		return events.APIGatewayProxyResponse{
			Body:       fmt.Sprintf("Error, %v", string(err.Error())),
			StatusCode: 500,
		}, nil
	}
	return events.APIGatewayProxyResponse{
		Body:       string(result),
		StatusCode: 200,
	}, nil
}

func main() {
	lambda.Start(handler)
}
