
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <time.h>
#include <locale.h>
#include <stdlib.h> 

#define PCAP_HEADER_BYTES       24
#define PCAP_DATA_HEADER_BYTES  16
#define ETH_DST_ADDR_BYTES      6
#define ETH_SRC_ADDR_BYTES      6
#define ETH_PROTOCOL_BYTES      2
#define IP_VERSION_BYTES        1
#define IP_HEADER_BYTES         1
#define IP_TYPE_BYTES           1
#define IP_LENGTH_BYTES         2
#define IP_ID_BYTES             2
#define IP_FLAG_BYTES           2
#define IP_TIME_BYTES           1
#define IP_PROTOCOL_BYTES       1
#define IP_CHECKSUM_BYTES       2
#define IP_SRC_ADDR_BYTES       4
#define IP_DST_ADDR_BYTES       4
#define UDP_DST_PORT_BYTES      2
#define UDP_SRC_PORT_BYTES      2
#define UDP_LENGTH_BYTES        2
#define UDP_CHECKSUM_BYTES      2
#define IP_PROTOCOL_DEF        0x0800
#define IP_VERSION_DEF         0x4
#define IP_HEADER_LENGTH_DEF   0x5
#define IP_TYPE_DEF            0x0
#define IP_FLAGS_DEF           0x4
#define TIME_TO_LIVE           0xe
#define UDP_PROTOCOL_DEF       0x11

unsigned short udp_sum_calc( unsigned char *ip_src_addr, unsigned char *ip_dst_addr, unsigned char *ip_protocol, 
                             unsigned char *ip_length, unsigned char *udp_src_port, unsigned char *udp_dst_port, 
                             unsigned char *udp_length, unsigned char *udp_data)
{
    unsigned short padd = 0;
    unsigned int sum = 0;	
    int udp_len = ((udp_length[0] << 8) | udp_length[1]);
    int data_length = udp_len - (UDP_CHECKSUM_BYTES + UDP_LENGTH_BYTES + UDP_DST_PORT_BYTES + UDP_SRC_PORT_BYTES);

	// Find out if the length of data is even or odd number. If odd,
	// add a padding byte = 0 at the end of packet
	if ( (data_length & 1) == 1 )
    {
		padd=1;
		udp_data[data_length]=0;
	}
	
	// add the UDP pseudo header which contains the IP source and destinationn addresses
	for (int i=0; i<4; i=i+2)
    {
		sum += ((ip_src_addr[i]<<8)&0xFF00)+(ip_src_addr[i+1]&0xFF);
	}

    for (int i=0; i<4; i=i+2)
    {
		sum += ((ip_dst_addr[i]<<8)&0xFF00)+(ip_dst_addr[i+1]&0xFF); 	
	}

    sum += ip_protocol[0];
    sum += (((unsigned short)ip_length[0]<<8)&0xFF00)+(ip_length[1]&0xFF) - 20;
    sum += (((unsigned short)udp_dst_port[0]<<8)&0xFF00)+(udp_dst_port[1]&0xFF);
    sum += (((unsigned short)udp_src_port[0]<<8)&0xFF00)+(udp_src_port[1]&0xFF);
    sum += (((unsigned short)udp_length[0]<<8)&0xFF00)+(udp_length[1]&0xFF);

    // make 16 bit words out of every two adjacent 8 bit words and 
	// calculate the sum of all 16 bit words
	for (int i=0; i < data_length; i += 2)
    {
        sum += (((unsigned short)udp_data[i]<<8)&0xFF00);
        sum += (udp_data[i+1]&0xFF);
	}	

	// keep only the last 16 bits of the 32 bit calculated sum and add the carries
	while (sum >> 16 != 0)
    {
		sum = (sum & 0xFFFF) + (sum >> 16);
    }

	// Take the one's complement of sum
	sum = ~sum;

    return sum;
}

int read_udp_packet(FILE *source, unsigned char *packet_data)
{
    unsigned char eth_dst_addr[ETH_DST_ADDR_BYTES];
    unsigned char eth_src_addr[ETH_SRC_ADDR_BYTES];
    unsigned char eth_protocol[ETH_PROTOCOL_BYTES];
    unsigned char ip_version[IP_VERSION_BYTES];
    unsigned char ip_header[IP_HEADER_BYTES];
    unsigned char ip_type[IP_TYPE_BYTES];
    unsigned char ip_length[IP_LENGTH_BYTES];
    unsigned char ip_id[IP_ID_BYTES];
    unsigned char ip_flag[IP_FLAG_BYTES];
    unsigned char ip_time[IP_TIME_BYTES];
    unsigned char ip_protocol[IP_PROTOCOL_BYTES];
    unsigned char ip_checksum[IP_CHECKSUM_BYTES];
    unsigned char ip_dst_addr[IP_SRC_ADDR_BYTES];
    unsigned char ip_src_addr[IP_DST_ADDR_BYTES];
    unsigned char udp_dst_port[UDP_DST_PORT_BYTES];
    unsigned char udp_src_port[UDP_SRC_PORT_BYTES];
    unsigned char udp_length[UDP_LENGTH_BYTES];
    unsigned char udp_checksum[UDP_CHECKSUM_BYTES];
    unsigned char udp_data[1024];
    unsigned short udp_data_length = 0, crc = 0, checksum = 0;
    int p = 0;

    if ( feof(source) ) return 0;

    fread(eth_dst_addr, 1, ETH_DST_ADDR_BYTES, source);
    fread(eth_src_addr, 1, ETH_SRC_ADDR_BYTES, source);
    fread(eth_protocol, 1, ETH_PROTOCOL_BYTES, source);
    if ( (((unsigned int)eth_protocol[0] << 8) | (unsigned int)eth_protocol[1]) != IP_PROTOCOL_DEF ) 
        return 0;

    fread(ip_version, 1, IP_VERSION_BYTES, source);
    if ( (ip_version[0] >> 4) != IP_VERSION_DEF ) 
        return 0;
    ip_header[0] = ip_version[0] & 0xF;

    fread(ip_type, 1, IP_TYPE_BYTES, source);
    fread(ip_length, 1, IP_LENGTH_BYTES, source);
    fread(ip_id, 1, IP_ID_BYTES, source);
    fread(ip_flag, 1, IP_FLAG_BYTES, source);
    fread(ip_time, 1, IP_TIME_BYTES, source);
    fread(ip_protocol, 1, IP_PROTOCOL_BYTES, source);
    if ( ip_protocol[0] != UDP_PROTOCOL_DEF ) 
        return 0;

    fread(ip_checksum, 1, IP_CHECKSUM_BYTES, source);
    fread(ip_src_addr, 1, IP_SRC_ADDR_BYTES, source);
    fread(ip_dst_addr, 1, IP_DST_ADDR_BYTES, source);
    fread(udp_dst_port, 1, UDP_DST_PORT_BYTES, source);
    fread(udp_src_port, 1, UDP_SRC_PORT_BYTES, source);
    fread(udp_length, 1, UDP_LENGTH_BYTES, source);
    fread(udp_checksum, 1, UDP_CHECKSUM_BYTES, source);

    // get the UDP data
    udp_data_length = (((unsigned int)udp_length[0] << 8) | (unsigned int)udp_length[1]);
    udp_data_length -= (UDP_CHECKSUM_BYTES + UDP_LENGTH_BYTES + UDP_DST_PORT_BYTES + UDP_SRC_PORT_BYTES);
    fread(udp_data, 1, udp_data_length, source);

    // calculate the checksum
    crc = udp_sum_calc( ip_src_addr, ip_dst_addr, ip_protocol, ip_length, udp_src_port, udp_dst_port, udp_length, udp_data );
    checksum = ((unsigned int)udp_checksum[0] << 8) | (unsigned int)udp_checksum[1];
    if ( checksum != crc ) 
    {
        fprintf( stderr, "ERROR: Checksum mismatch -- %04x != %04x\n", crc, checksum);
        return 0;
    }

    for ( int i = 0; i < udp_data_length; i++ )
    {
        packet_data[i] = udp_data[i];
    }

    return udp_data_length;
}

int main(int argc, char **argv)
{
    // if reading pcap files
    unsigned char pcap_header[PCAP_HEADER_BYTES];
    unsigned char pcap_data_header[PCAP_DATA_HEADER_BYTES];

    if ( argc < 2 )
    {
        printf("Missing input file.\n");
        return 1;
    }

    FILE * src_file = fopen( argv[1], "rb");
    if (src_file == NULL) 
    {
        printf("Can't open file %s\n", argv[1]);
        return 1;
    }

    unsigned char udp_packet[2048];

    // remove PCAP headers
    fread(pcap_header, 1, PCAP_HEADER_BYTES, src_file);

    /////////////////////////////////
    // Read UDP Packets
    while ( !feof(src_file) )
    {
        // remove PCAP data header
        fread(pcap_data_header, 1, PCAP_DATA_HEADER_BYTES, src_file);

        // read the UDP packet	
        int size = read_udp_packet( src_file, udp_packet );
        
        // print packet data
        for ( int i = 0; i < size; i++ )
        {
            printf( "%c", udp_packet[i] );
        }
/*
        // print packets
        for ( int i = 0; i < size; i++ )
        {
            if ( i % 16 == 0 ) printf( "\n" );
            if ( i % 16 == 8 ) printf( " " );
            printf( "%02x ", udp_packet[i] );
        }
        printf( "\n" );
*/        
    }

    printf( "\n" );

    return 0;
}

