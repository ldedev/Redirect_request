module models

/**
 "url": "/ac/api/v1/listmesa/",
	"body": "",
	"id": "737df2c7-ddb6-4c3d-b704-96036065e08a",
	"cnpj_cpf": "57635355000174",
	"concluded": false,
	"waitingtime": 1660597918,
	"response": {
		"data_received": false,
		"body": ""
	},
	"worker": true,
	"work_time": 1660597502
*/

pub struct ContextRequest {
pub mut:
	status		Status
	url         string
	body        string
	method      string
	id          string
	cnpj_cpf    string
	concluded   bool
	waitingtime i64
	response    struct  {
		data_received bool
		body          string
	}

	worker    bool
	work_time i64
}
