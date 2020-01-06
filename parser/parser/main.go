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
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type resumeFormat struct {
	Value struct {
		Document string `json:"ParsedDocument"`
	} `json:"Value"`
}
type contactInfoFormat struct {
	Resume struct {
		Structured struct {
			ContactInfo struct {
				PersonName struct {
					FormattedName string `json:"FormattedName"`
					GivenName     string `json:"GivenName"`
					MiddleName    string `json:"MiddleName"`
					FamilyName    string `json:"FamilyName"`
				} `json:PersonName`
			} `json:"ContactInfo"`
		} `json:"StructuredXMLResume"`
	} `json:"Resume"`
}

type payload struct {
	FileBytes string `json:"FileBytes"`
}

var (
	// ErrNon200Response non 200 status code in response
	ErrNon200Response = errors.New("Non 200 Response found")

	// Sovren related info

)

var accountID = os.Getenv("SOVREN_ACCOUNT_ID")
var serviceKey = os.Getenv("SOVREN_SERVICE_KEY")

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	f, err := os.Open("sample_resume.doc")
	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}
	// create a new buffer base on file size
	fInfo, _ := f.Stat()
	var size int64 = fInfo.Size()
	buf := make([]byte, size)

	// read file content into buffer
	fReader := bufio.NewReader(f)
	fReader.Read(buf)
	encodedFile := base64.StdEncoding.EncodeToString(buf)
	defer f.Close()

	payloadString := fmt.Sprintf(`{
			"DocumentAsBase64String": "%s",
			"RevisionDate": "%s"
	}`, encodedFile, string(time.Now().Format("2006-01-02")))
	payloadBytes := []byte(payloadString)
	// fmt.Printf("Here is the payload: %s", payloadString)
	req, err := http.NewRequest(
		"POST",
		"https://rest.resumeparsing.com/v9/parser/resume",
		bytes.NewBuffer(payloadBytes),
	)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Sovren-AccountId", accountID)
	req.Header.Set("Sovren-ServiceKey", serviceKey)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		bodyBytes, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			fmt.Println(err)
		}
		//		bodyString := string(bodyBytes)
		var resume resumeFormat
		var contactInfo contactInfoFormat

		err = json.Unmarshal(bodyBytes, &resume)
		if nil != err {
			fmt.Println("Error unmarshalling from resume", err)
			return events.APIGatewayProxyResponse{
				Body:       fmt.Sprintf("Error, %v", string(err.Error())),
				StatusCode: 500,
			}, nil
		}
		err = json.Unmarshal([]byte(resume.Value.Document), &contactInfo)
		if nil != err {
			fmt.Println("Error unmarshalling from resume document", err)
			return events.APIGatewayProxyResponse{
				Body:       fmt.Sprintf("Error, %v", string(err.Error())),
				StatusCode: 500,
			}, nil
		}
		fmt.Println(contactInfo.Resume.Structured.ContactInfo)
		js, err := json.Marshal(contactInfo.Resume.Structured.ContactInfo)
		if err != nil {
			fmt.Println("Error unmarshalling from contactInfo", err)
			return events.APIGatewayProxyResponse{
				Body:       fmt.Sprintf("Error, %v", string(err.Error())),
				StatusCode: 500,
			}, nil
		}

		return events.APIGatewayProxyResponse{
			Body:       string(js),
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
