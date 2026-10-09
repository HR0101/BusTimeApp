from datetime import date, datetime
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class Model(BaseModel):
    model_config = ConfigDict(extra='forbid')


class StopTime(Model):
    stop_id: str = Field(min_length=1, max_length=80)
    time: str = Field(pattern=r'^\d{1,2}:\d{2}$')

    @field_validator('time')
    @classmethod
    def normalize_time(cls, value):
        hour, minute = map(int, value.split(':'))
        if not 0 <= hour < 24 or not 0 <= minute < 60:
            raise ValueError('Time must be between 0:00 and 23:59')
        return f'{hour}:{minute:02d}'


class Trip(Model):
    id: str = Field(pattern=r'^[A-Za-z0-9_-]{1,80}$')
    route_id: str = Field(min_length=1, max_length=80)
    schedule_id: str = Field(min_length=1, max_length=80)
    stops: list[StopTime] = Field(min_length=2, max_length=12)
    note: str | None = Field(default=None, max_length=500)

    @model_validator(mode='after')
    def times_are_in_service_order(self):
        def minutes(stop):
            hour, minute = map(int, stop.time.split(':'))
            return (hour + (24 if hour < 4 else 0)) * 60 + minute
        values = [minutes(stop) for stop in self.stops]
        if any(a >= b for a, b in zip(values, values[1:])):
            raise ValueError('Stop times must increase within the 4:00-to-4:00 service day')
        return self


class Schedule(Model):
    id: str = Field(pattern=r'^[A-Za-z0-9_-]{1,80}$')
    route_id: str = Field(min_length=1, max_length=80)
    kind: Literal['weekday', 'weekend', 'holiday', 'special']
    service_date: date | None = None
    valid_from: date | None = None
    valid_until: date | None = None
    is_suspended: bool = False
    priority: int = Field(default=0, ge=0, le=100)

    @model_validator(mode='after')
    def validate_dates(self):
        if (self.kind == 'special') != (self.service_date is not None):
            raise ValueError('Only special schedules require a service_date')
        if self.valid_from and self.valid_until and self.valid_from > self.valid_until:
            raise ValueError('valid_until precedes valid_from')
        return self


class Operation(Model):
    operation: Literal['upsert', 'delete']
    trip: Trip | None = None
    id: str | None = None

    @model_validator(mode='after')
    def validate_target(self):
        if self.operation == 'upsert' and (self.trip is None or self.id is not None):
            raise ValueError('Upsert requires trip only')
        if self.operation == 'delete' and (not self.id or self.trip is not None):
            raise ValueError('Delete requires id only')
        return self


class Batch(Model):
    changes: list[Operation] = Field(min_length=1, max_length=1000)


class Publication(Batch):
    publish_at: datetime

    @field_validator('publish_at')
    @classmethod
    def timezone_required(cls, value):
        if value.tzinfo is None:
            raise ValueError('publish_at must include a timezone')
        return value
