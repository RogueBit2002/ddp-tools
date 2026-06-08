typedef unsigned char  unit8;
typedef unsigned short unit16;
typedef unsigned int   unit32;

void hxb_convert_seg(unit8 *data, int seed, int key)
{
	//int seed = hxb_header.length[0] << 16 | hxb_header.length[1] << 8 | hxb_header.length[2];
	//int seed = (size & 0xFF << 16) | (size & 0xFF << 8) | size >> 16 & 0xFF;
	unit32* p = (unit32*)(data + 0x10);
	for (int i = 0; i < (seed - 13) / 4; i++)
		p[i] ^= key;
}

void ddp_uncompress(unit8 *uncompr, unit32 uncomprlen, unit8 *compr, unit32 comprlen)
{
	unit32 curbyte = 0, i;
	unit32 act_uncomprlen = 0;
	while (act_uncomprlen < uncomprlen)
	{
		unit8 flag = compr[curbyte++];
		unit32 offset, copy_len;

		if (flag < 0x1D)
		{
			copy_len = flag + 1;
			offset = 0;
		}
		else if (flag == 0x1D)
		{
			copy_len = compr[curbyte++] + 0x1E;
			offset = 0;
		}
		else if (flag == 0x1E)
		{
			copy_len = ((compr[curbyte] << 8) | compr[curbyte + 1]) + 0x11E;
			curbyte += 2;
			offset = 0;
		}
		else if (flag == 0x1F)
		{
			copy_len = (compr[curbyte] << 24) | (compr[curbyte + 1] << 16)
				| (compr[curbyte + 2] << 8) | compr[curbyte + 3];
			curbyte += 4;
			offset = 0;
		}
		else
		{
			if (flag < 0x80)
			{
				if ((flag & 0x60) == 0x20)
				{
					copy_len = flag & 3;
					offset = (flag >> 2) & 7;
				}
				else if ((flag & 0x60) == 0x40)
				{
					copy_len = (flag & 0x1f) + 4;
					offset = compr[curbyte++];
				}
				else
				{
					offset = ((flag & 0x1F) << 8) | compr[curbyte++];
					flag = compr[curbyte++];
					switch (flag)
					{
					case 0xFE:
						copy_len = ((compr[curbyte] << 8) | compr[curbyte + 1]) + 0x102;
						curbyte += 2;
						break;
					case 0xFF:
						copy_len = (compr[curbyte] << 24) | (compr[curbyte + 1] << 16) | (compr[curbyte + 2] << 8) | compr[curbyte + 3];
						curbyte += 4;
						break;
					default:
						copy_len = flag + 4;
					}
				}
			}
			else
			{
				copy_len = (flag >> 5) & 3;
				offset = ((flag & 0x1F) << 8) | compr[curbyte++];
			}
			offset++;
			copy_len += 3;
		}

		if (offset)
		{
			for (i = 0; i < copy_len; i++)
			{
				uncompr[act_uncomprlen] = uncompr[act_uncomprlen - offset];
				act_uncomprlen++;
			}
		}
		else
		{
			for (i = 0; i < copy_len; i++)
				uncompr[act_uncomprlen++] = compr[curbyte++];
		}
	}
}
