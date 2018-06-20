#!/usr/bin/perl 
#use strict;
use warnings;
use threads;
use threads::shared;
use Thread::Semaphore;

### Variables Globales ###

#Variables de menu y contadores
my $salir = 0;
my $idHilo : shared= 0;

# Semaforos y contadores
my $inSem = Thread::Semaphore->new();
my $mxSem = Thread::Semaphore->new();
my $wrtSem = Thread::Semaphore->new();
my $ctr : shared = 0;
my @colaEjecucion;


# Comandos disponibles aca
print "Comandos disponibles:\n";
print " - crear-lector [tiempo-lectura] [tiempo-inicio]\n";
print " - crear-escritor [tiempo-escritura] [tiempo-inicio]\n";
print " - listar <[escritores lectores todos]>\n";
print " - salir\n"  ;


while($salir == 0) {
  chomp(my $input = <STDIN>);
    
    my @splittedInput = split / /, $input;
    my $parametersCount = scalar @splittedInput;

    my $command = $splittedInput[0];
        
    if( $command eq "crear-lector") {
        # crear hilo de lector            
        
        $idHilo +=1; 
        my $inicio = 0;

        if($parametersCount < 2) {
            print "Incorrecto: faltan parametros\n";
            return;
        }

        if($parametersCount == 3) {
            $inicio = $splittedInput[2];
        }


        if($splittedInput[1] eq $splittedInput[1]+0 && $inicio eq $inicio+0) {
            my $t = threads->create('hiloLector', $idHilo, $splittedInput[1], $inicio);
            
            push @colaEjecucion, $t;
            
        }
        else {
            print 'Parametros incorrectos\n';
            return;
        }
        
    }
    elsif($command eq "crear-escritor") {
        # crear hilo de escritor

        $idHilo +=1;

        my $inicio = 0;

        if($parametersCount < 2) {
            print "Incorrecto: faltan parametros\n";
            return;
        }

        if($parametersCount == 3) {
            $inicio = $splittedInput[2];
        }

        if($splittedInput[1] eq $splittedInput[1]+0 && $inicio eq $inicio+0) {
            my $t = threads->create('hiloEscritor', $idHilo, $splittedInput[1], $inicio);
            push @colaEjecucion, $t;
        }
        else {
            print 'Parametros incorrectos\n';
            return;
        }
    }
    elsif( $command eq "listar") {
      listar();

    }
    elsif( $command eq "salir") {
        $salir = 1;
    }
    else {
        print 'Comando invalido\n';
    }
    
}


sub hiloLector {
      
    my ($id,$sleep, $inicio) = @_;
    my $self = threads->self(); 
    my $tid = $self->tid();
    my $out = $tid;

    sleep($inicio);

    $inSem->down();
    $mxSem->down();

    $ctr += 1;
    if($ctr == 1) {
        $wrtSem->down();
    }

    $mxSem->up();
    $inSem->up();


    #print "Soy el Hilo Lector Id: ".$id . " , estoy ejecutando: ".$sleep . "seg\n" ;
    my $linea = "Soy el Hilo Lector Id: ".$id . " , estoy ejecutando: ".$sleep . "seg\n" ;
    escribirLog($linea);
    
    sleep($sleep);

    $mxSem->down();

    $ctr -= 1;
    if($ctr == 0) {
        $wrtSem->up();
    }

    $mxSem->up();
   
    #print "--Lector-id:",$id," Finalizado\n";
    $linea =  "--Lector-id:",$id," Finalizado\n";
    escribirLog($linea); 
    return $out
}

sub hiloEscritor {
    my ($id,$sleep, $inicio) = @_;
    my $self = threads->self(); # referencia al objeto thread
    my $tid = $self->tid();
    my $out = $tid;

    sleep($inicio);

    $inSem->down();
    $wrtSem->down();

    #print "Soy el Hilo Escritor Id: ".$id . " , estoy esribiendo por: ".$sleep . "seg\n";
    my $linea = "Soy el Hilo Escritor Id: ".$id . " , estoy esribiendo por: ".$sleep . "seg\n";
    escribirLog($linea);
    sleep($sleep);

    $wrtSem->up();
    $inSem->up();
    
    #print "Escritor-id:",$id," Finalizado\n";
    $linea = "Escritor-id:".$id." Finalizado\n";
    escribirLog($linea);

    return $out;
   
}


sub escribirLog {
    
    my ($linea) = @_;
     
    open(LECTURA,">> log.txt") || die "No pudo abrirse: $!";
    print LECTURA "$linea";
    close(LECTURA);
    
}

sub listar {
  
  foreach $hilo (@colaEjecucion) {
   
   #ejecutando
   if ($hilo->is_running()){
    print "Soy el hilo tid: " ,  $hilo->tid() , " y estoy ejecutando\n";
    
   }
   #finalizados
   if ($hilo->is_joinable()) {
    print "Soy el hilo tid: " ,  $hilo->tid() , " y termine\n";
    
    
   }
  }
    
}
  
