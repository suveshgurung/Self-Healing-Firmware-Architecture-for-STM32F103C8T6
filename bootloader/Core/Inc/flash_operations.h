/*
 * flash_operations.h
 *
 *  Created on: Jul 16, 2026
 *      Author: subbu
 */

#ifndef INC_FLASH_OPERATIONS_H_
#define INC_FLASH_OPERATIONS_H_

/* Macros define */
#define RDPRT_KEY	0x00A5
#define KEY_1		0x45670123
#define KEY_2		0xCDEF89AB
/* Macros define end */

void flash_unlock(void);
void flash_erase(uint32_t start_address);
void flash_program(void);

#endif /* INC_FLASH_OPERATIONS_H_ */
