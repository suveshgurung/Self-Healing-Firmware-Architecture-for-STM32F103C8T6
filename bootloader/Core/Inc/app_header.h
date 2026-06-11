/*
 * app_header.h
 *
 *  Created on: Jun 11, 2026
 *      Author: subbu
 */

#ifndef INC_APP_HEADER_H_
#define INC_APP_HEADER_H_

typedef struct {
	uint32_t magic_number;
	uint32_t app_size;
	uint32_t crc;
} app_header_t;

#define	APP_MAGIC_NUMBER	0xABCD1234;

#endif /* INC_APP_HEADER_H_ */
