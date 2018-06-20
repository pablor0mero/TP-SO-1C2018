package Thread::Queue::Priority;
 
use strict;
use warnings;
 
our $VERSION = '1.03';
$VERSION = eval $VERSION;
 
use threads::shared 1.21;
use Scalar::Util qw(looks_like_number);
 
# Carp errors from threads::shared calls should complain about caller
our @CARP_NOT = ("threads::shared");
 
sub new {
    my $class = shift;
    my %queue :shared = ();
    my %self :shared = (
        '_queue'   => \%queue,
        '_count'   => 0,
        '_ended'     => 0,
    );
    return bless(\%self, $class);
}
 
# add items to the tail of a queue
sub enqueue {
    my ($self, $item, $priority) = @_;
    lock(%{$self});
 
    # if the queue has "ended" then we can't enqueue anything
    if ($self->{'_ended'}) {
        require Carp;
        Carp::croak("'enqueue' method called on queue that has been 'end'ed");
    }
 
    my $queue = $self->{'_queue'};
    $priority = defined($priority) ? $self->_validate_priority($priority) : 50;
 
    # if the priority group hasn't been created then create it
    my @group :shared = ();
    $queue->{$priority} = \@group unless exists($queue->{$priority});
 
    # increase our global count
    ++$self->{'_count'};
 
    # add the new item to the priority list and signal that we're done
    push(@{$self->{'_queue'}->{$priority}}, shared_clone($item)) and cond_signal(%{$self});
}
 
# return a count of the number of items on a queue
sub pending {
    my $self = shift;
    lock(%{$self});
 
    # return undef if the queue has ended and is empty
    return if $self->{'_ended'} && !$self->{'_count'};
    return $self->{'_count'};
}
 
# indicate that no more data will enter the queue
sub end {
    my $self = shift;
    lock(%{$self});
 
    # no more data is coming
    $self->{'_ended'} = 1;
 
    # try to release at least one blocked thread
    cond_signal(%{$self});
}
 
# return 1 or more items from the head of a queue, blocking if needed
sub dequeue {
    my $self = shift;
    lock(%{$self});
 
    my $queue = $self->{'_queue'};
    my $count = scalar(@_) ? $self->_validate_count(shift(@_)) : 1;
 
    # wait for requisite number of items
    cond_wait(%{$self}) while (($self->{'_count'} < $count) && ! $self->{'_ended'});
    cond_signal(%{$self}) if (($self->{'_count'} > $count) || $self->{'_ended'});
 
    # if no longer blocking, try getting whatever is left on the queue
    return $self->dequeue_nb($count) if ($self->{'_ended'});
 
    # return single item
    if ($count == 1) {
        for my $priority (sort keys %{$queue}) {
            if (scalar(@{$queue->{$priority}})) {
                --$self->{'_count'};
                return shift(@{$queue->{$priority}});
            }
        }
        return;
    }
 
    # return multiple items
    my @items = ();
    for (1 .. $count) {
        for my $priority (sort keys %{$queue}) {
            if (scalar(@{$queue->{$priority}})) {
                --$self->{'_count'};
                push(@items, shift(@{$queue->{$priority}}));
            }
        }
    }
    return @items;
}
 
# return items from the head of a queue with no blocking
sub dequeue_nb {
    my $self = shift;
    lock(%{$self});
 
    my $queue = $self->{'_queue'};
    my $count = scalar(@_) ? $self->_validate_count(shift(@_)) : 1;
 
    # return single item
    if ($count == 1) {
        for my $priority (sort keys %{$queue}) {
            if (scalar(@{$queue->{$priority}})) {
                --$self->{'_count'};
                return shift(@{$queue->{$priority}});
            }
        }
        return;
    }
 
    # return multiple items
    my @items = ();
    for (1 .. $count) {
        for my $priority (sort keys %{$queue}) {
            if (scalar(@{$queue->{$priority}})) {
                --$self->{'_count'};
                push(@items, shift(@{$queue->{$priority}}));
            }
        }
    }
 
    return @items;
}
 
# return items from the head of a queue, blocking if needed up to a timeout
sub dequeue_timed {
    my $self = shift;
    lock(%{$self});
 
    my $queue = $self->{'_queue'};
    my $timeout = scalar(@_) ? $self->_validate_timeout(shift(@_)) : -1;
    my $count = scalar(@_) ? $self->_validate_count(shift(@_)) : 1;
 
    # timeout may be relative or absolute
    # convert to an absolute time for use with cond_timedwait()
    # so if the timeout is less than a year then we assume it's relative
    $timeout += time() if ($timeout < 322000000); # more than one year
 
    # wait for requisite number of items, or until timeout
    while ($self->{'_count'} < $count && !$self->{'_ended'}) {
        last unless cond_timedwait(%{$self}, $timeout);
    }
    cond_signal(%{$self}) if (($self->{'_count'} > $count) || $self->{'_ended'});
 
    # get whatever we need off the queue if available
    return $self->dequeue_nb($count);
}
 
# return an item without removing it from a queue
sub peek {
    my $self = shift;
    lock(%{$self});
 
    my $queue = $self->{'_queue'};
    my $index = scalar(@_) ? $self->_validate_index(shift(@_)) : 0;
 
    for my $priority (sort keys %{$queue}) {
        my $size = scalar(@{$queue->{$priority}});
        if ($index < $size) {
            return $queue->{$priority}->[$index];
        } else {
            $index = ($index - $size);
        }
    }
 
    return;
}
 
### internal functions ###
 
# check value of the requested index
sub _validate_index {
    my ($self, $index) = @_;
 
    if (!defined($index) || !looks_like_number($index) || (int($index) != $index)) {
        require Carp;
        my ($method) = (caller(1))[3];
        my $class_name = ref($self);
        $method =~ s/${class_name}:://;
        $index = 'undef' unless defined($index);
        Carp::croak("Invalid 'index' argument (${index}) to '${method}' method");
    }
 
    return $index;
}
 
# check value of the requested count
sub _validate_count {
    my ($self, $count) = @_;
 
    if (!defined($count) || !looks_like_number($count) || (int($count) != $count) || ($count < 1)) {
        require Carp;
        my ($method) = (caller(1))[3];
        my $class_name = ref($self);
        $method =~ s/${class_name}:://;
        $count = 'undef' unless defined($count);
        Carp::croak("Invalid 'count' argument (${count}) to '${method}' method");
    }
 
    return $count;
}
 
# check value of the requested timeout
sub _validate_timeout {
    my ($self, $timeout) = @_;
 
    if (!defined($timeout) || !looks_like_number($timeout)) {
        require Carp;
        my ($method) = (caller(1))[3];
        my $class_name = ref($self);
        $method =~ s/${class_name}:://;
        $timeout = 'undef' unless defined($timeout);
        Carp::croak("Invalid 'timeout' argument (${timeout}) to '${method}' method");
    }
 
    return $timeout;
}
 
# check value of the requested timeout
sub _validate_priority {
    my ($self, $priority) = @_;
 
    if (!defined($priority) || !looks_like_number($priority) || (int($priority) != $priority) || ($priority < 0)) {
        require Carp;
        my ($method) = (caller(1))[3];
        my $class_name = ref($self);
        $method =~ s/${class_name}:://;
        $priority = 'undef' unless defined($priority);
        Carp::croak("Invalid 'priority' argument (${priority}) to '${method}' method");
    }
 
    return $priority;
}
 
1;
 